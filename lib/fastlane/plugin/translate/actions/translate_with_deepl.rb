# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'deepl'

module Fastlane
  module Actions
    module SharedValues
      TRANSLATE_WITH_DEEPL_TRANSLATED_COUNT = :TRANSLATE_WITH_DEEPL_TRANSLATED_COUNT
      TRANSLATE_WITH_DEEPL_TARGET_LANGUAGE = :TRANSLATE_WITH_DEEPL_TARGET_LANGUAGE
      TRANSLATE_WITH_DEEPL_BACKUP_FILE = :TRANSLATE_WITH_DEEPL_BACKUP_FILE
    end

    class TranslateWithDeeplAction < Action
      def self.run(params)
        # Load required modules
        require_relative '../language_registry'
        require_relative '../deepl_language_mapper'
        require_relative '../translation_progress'

        # Setup and validation
        setup_deepl_client(params)
        xcstrings_path = find_xcstrings_file(params[:xcstrings_path])
        backup_file = create_backup(xcstrings_path)

        # Parse xcstrings file
        xcstrings_data = JSON.parse(File.read(xcstrings_path))
        source_language = xcstrings_data['sourceLanguage']
        available_languages = extract_available_languages(xcstrings_data)

        # Filter languages supported by DeepL
        supported_languages = Fastlane::Translate::DeepLLanguageMapper.supported_languages_from_list(available_languages)
        unsupported_languages = Fastlane::Translate::DeepLLanguageMapper.unsupported_languages(available_languages)

        UI.important("⚠️  Languages not supported by DeepL: #{unsupported_languages.map { |l| "#{Fastlane::Translate::LanguageRegistry.language_name(l)} (#{l})" }.join(', ')}") if unsupported_languages.any?

        UI.user_error!('❌ No DeepL-supported languages found in xcstrings file') if supported_languages.empty?

        # Language selection
        target_language = select_target_language(params[:target_language], supported_languages, xcstrings_data)

        # Formality detection
        formality = detect_and_ask_formality(target_language, params[:formality])

        # Translate the selected language
        translated_count = translate_language(xcstrings_data, xcstrings_path, source_language, target_language, formality, params)

        # Set shared values for other actions
        Actions.lane_context[SharedValues::TRANSLATE_WITH_DEEPL_TRANSLATED_COUNT] = translated_count
        Actions.lane_context[SharedValues::TRANSLATE_WITH_DEEPL_TARGET_LANGUAGE] = target_language
        Actions.lane_context[SharedValues::TRANSLATE_WITH_DEEPL_BACKUP_FILE] = backup_file

        UI.success('🎉 Translation completed!')
        UI.message("📊 Translated #{translated_count} strings for #{Fastlane::Translate::LanguageRegistry.language_name(target_language)} (#{target_language})")
        UI.message("📄 Backup saved: #{backup_file}")
        UI.message('🗑️  You can delete the backup after verifying results')

        translated_count
      end

      def self.setup_deepl_client(params)
        DeepL.configure do |config|
          config.auth_key = params[:api_token]
          config.host = params[:free_api] ? 'https://api-free.deepl.com' : 'https://api.deepl.com'
        end

        # Test API key
        begin
          DeepL.usage
          UI.success('✅ DeepL API key validated')
        rescue DeepL::Exceptions::AuthorizationFailed
          UI.user_error!('❌ Invalid DeepL API key. Get one at: https://www.deepl.com/pro#developer')
        rescue StandardError => e
          UI.user_error!("❌ DeepL API connection failed: #{e.message}")
        end
      end

      def self.find_xcstrings_file(provided_path)
        if provided_path
          UI.user_error!("❌ Localizable.xcstrings file not found at: #{provided_path}") unless File.exist?(provided_path)
          return provided_path
        end

        # Search for xcstrings files
        xcstrings_files = Dir.glob('**/Localizable.xcstrings')

        UI.user_error!('❌ No Localizable.xcstrings files found. Please specify the path with xcstrings_path parameter.') if xcstrings_files.empty?

        if xcstrings_files.count == 1
          UI.message("📁 Found xcstrings file: #{xcstrings_files.first}")
          return xcstrings_files.first
        end

        # Multiple files found, let user choose
        UI.message('📁 Multiple xcstrings files found:')
        UI.select('Choose file:', xcstrings_files)
      end

      def self.create_backup(xcstrings_path)
        timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
        backup_path = "#{xcstrings_path}.backup_#{timestamp}"
        FileUtils.cp(xcstrings_path, backup_path)
        UI.message("💾 Backup created: #{backup_path}")
        backup_path
      end

      def self.extract_available_languages(xcstrings_data)
        languages = Set.new

        xcstrings_data['strings'].each do |_, string_data|
          next unless string_data['localizations']

          string_data['localizations'].each_key { |lang| languages.add(lang) }
        end

        # Remove source language from target options
        source_lang = xcstrings_data['sourceLanguage']
        languages.delete(source_lang)

        languages.to_a.sort
      end

      def self.select_target_language(param_language, available_languages, xcstrings_data)
        if param_language
          UI.user_error!("❌ Language '#{param_language}' not found in xcstrings file. Available: #{available_languages.join(', ')}") unless available_languages.include?(param_language)
          return param_language
        end

        # Calculate translation percentages for each language
        language_stats = calculate_translation_stats(xcstrings_data, available_languages)

        # Create display list with language names and translation status
        language_options = available_languages.map do |lang_code|
          lang_name = Fastlane::Translate::LanguageRegistry.language_name(lang_code)
          stats = language_stats[lang_code]
          percentage = ((stats[:translated].to_f / stats[:total]) * 100).round(1)

          display_name = "#{lang_name} (#{lang_code}): #{percentage}% translated (#{stats[:untranslated]} remaining)"

          # Add formality indicator
          display_name += ' [supports formality]' if Fastlane::Translate::DeepLLanguageMapper.supports_formality?(lang_code)

          { display: display_name, code: lang_code, stats: }
        end

        # Sort by most untranslated first (prioritize languages that need work)
        language_options.sort_by! { |opt| -opt[:stats][:untranslated] }

        UI.message('📋 Available languages for translation:')
        selected_display = UI.select('Choose target language:', language_options.map { |opt| opt[:display] })

        # Find the corresponding language code
        selected_option = language_options.find { |opt| opt[:display] == selected_display }
        selected_option[:code]
      end

      def self.calculate_translation_stats(xcstrings_data, languages)
        stats = {}

        languages.each do |lang_code|
          total = 0
          translated = 0

          xcstrings_data['strings'].each do |string_key, string_data|
            next if string_key.empty?
            next unless string_data.dig('localizations', lang_code)

            total += 1
            localization = string_data.dig('localizations', lang_code, 'stringUnit')

            if localization && localization['state'] == 'translated' &&
               localization['value'] && !localization['value'].empty?
              translated += 1
            end
          end

          stats[lang_code] = {
            total:,
            translated:,
            untranslated: total - translated
          }
        end

        stats
      end

      def self.detect_and_ask_formality(target_language, formality_param)
        return formality_param if formality_param
        return nil unless Fastlane::Translate::DeepLLanguageMapper.supports_formality?(target_language)

        lang_name = Fastlane::Translate::LanguageRegistry.language_name(target_language)
        choice = UI.select(
          "🎭 #{lang_name} supports formality options. Choose style:",
          ['default', 'more (formal)', 'less (informal)', 'prefer_more (formal if possible)', 'prefer_less (informal if possible)']
        )

        case choice
        when 'more (formal)' then 'more'
        when 'less (informal)' then 'less'
        when 'prefer_more (formal if possible)' then 'prefer_more'
        when 'prefer_less (informal if possible)' then 'prefer_less'
        end
      end

      def self.translate_language(xcstrings_data, xcstrings_path, source_language, target_language, formality, params)
        # Validate DeepL support
        UI.user_error!("❌ Language '#{target_language}' is not supported by DeepL") unless Fastlane::Translate::DeepLLanguageMapper.supported?(target_language)

        # Get DeepL language codes
        deepl_source = Fastlane::Translate::DeepLLanguageMapper.get_source_language(source_language)
        deepl_target = Fastlane::Translate::DeepLLanguageMapper.get_target_language(target_language)

        UI.message("🔄 Translating from #{deepl_source} to #{deepl_target}")

        # Progress setup
        progress = Fastlane::Translate::TranslationProgress.new(xcstrings_path, target_language)

        if progress.has_progress?
          summary = progress.progress_summary
          UI.message("📈 Found existing progress: #{summary[:translated_count]} strings translated")
          choice = UI.select('Continue from where you left off?', ['Yes, continue', 'No, start fresh'])
          progress.cleanup if choice == 'No, start fresh'
        end

        # Extract untranslated strings
        untranslated_strings = extract_untranslated_strings(
          xcstrings_data, source_language, target_language, progress.get_translated_strings
        )

        if untranslated_strings.empty?
          UI.success("✅ All strings already translated for #{target_language}")
          progress.cleanup
          return 0
        end

        UI.message("📝 Found #{untranslated_strings.count} untranslated strings")

        # Batch translation
        translated_count = translate_in_batches(
          untranslated_strings, deepl_source, deepl_target,
          formality, params[:batch_size], progress
        )

        # Update xcstrings file
        update_xcstrings_file(xcstrings_path, xcstrings_data, target_language,
                              progress.get_translated_strings)

        # Validation and cleanup
        validate_json_file(xcstrings_path)
        progress.cleanup

        translated_count
      end

      def self.extract_untranslated_strings(xcstrings_data, source_language, target_language, already_translated)
        untranslated = {}

        xcstrings_data['strings'].each do |string_key, string_data|
          next if string_key.empty? # Skip empty keys

          localization = string_data.dig('localizations', target_language, 'stringUnit')
          next unless localization

          # Check if untranslated (state: "new" and empty value)
          next unless localization['state'] == 'new' && (localization['value'].nil? || localization['value'].empty?)
          # Skip if already translated in progress
          next if already_translated[string_key]

          # Get source text from source language
          source_text = string_data.dig('localizations', source_language, 'stringUnit', 'value')
          next if source_text.nil? || source_text.empty?

          context = extract_string_context(string_key, string_data)
          untranslated[string_key] = {
            'source_text' => source_text,
            'context' => context
          }
        end

        untranslated
      end

      def self.extract_string_context(string_key, string_data)
        # Check for comment field in the string data
        comment = string_data['comment']
        return comment if comment && !comment.empty?

        # Fallback: use string key as minimal context if it's descriptive
        string_key.length > 50 ? nil : string_key
      end

      def self.translate_in_batches(untranslated_strings, source_lang, target_lang, formality, batch_size, progress)
        batches = untranslated_strings.each_slice(batch_size).to_a
        total_translated = 0

        batches.each_with_index do |batch, index|
          UI.message("🔄 Translating batch #{index + 1}/#{batches.count} (#{batch.count} strings)...")

          # Prepare batch for DeepL API
          texts_to_translate = batch.map { |_, data| data['source_text'] }

          retry_count = 0
          max_retries = 3

          begin
            # Build translation options (exclude source_lang and target_lang)
            translation_options = {}
            translation_options[:formality] = formality if formality

            # Get context from first item if available (DeepL applies to all)
            first_context = batch.first&.last&.dig('context')
            translation_options[:context] = first_context if first_context

            # Call DeepL with positional arguments for source_lang and target_lang
            translations = DeepL.translate(texts_to_translate, source_lang, target_lang, translation_options)

            # Save translations to progress
            translated_batch = {}
            batch.each_with_index do |(string_key, _), text_index|
              translated_text = translations.is_a?(Array) ? translations[text_index].text : translations.text
              translated_batch[string_key] = translated_text
            end

            progress.save_translated_strings(translated_batch)
            total_translated += translated_batch.size
            UI.success("✅ Batch #{index + 1} completed (#{translated_batch.size} strings)")
          rescue DeepL::Exceptions::AuthorizationFailed
            UI.user_error!('❌ Invalid DeepL API key')
          rescue DeepL::Exceptions::QuotaExceeded
            UI.user_error!('❌ DeepL quota exceeded. Upgrade your plan or wait for reset.')
          rescue DeepL::Exceptions::LimitExceeded
            action = handle_rate_limit_error(batch, index, batches.count)
            if action == :retry && retry_count < max_retries
              retry_count += 1
              retry
            elsif action == :skip
              next
            end
          rescue StandardError => e
            action = handle_translation_error(e, batch, index, batches.count)
            if action == :retry && retry_count < max_retries
              retry_count += 1
              retry
            elsif action == :skip
              next
            end
          end
        end

        total_translated
      end

      def self.handle_rate_limit_error(_batch, index, total_batches)
        choice = UI.select("⚠️ Rate limit exceeded for batch #{index + 1}/#{total_batches}",
                           ['Wait 60s and retry', 'Skip this batch', 'Abort translation'])
        case choice
        when 'Wait 60s and retry'
          UI.message('⏳ Waiting 60 seconds...')
          sleep(60)
          :retry
        when 'Skip this batch'
          UI.important("⏭️ Skipping batch #{index + 1}")
          :skip
        when 'Abort translation'
          UI.user_error!('❌ Translation aborted by user')
        end
      end

      def self.handle_translation_error(error, _batch, index, total_batches)
        UI.error("❌ Translation error for batch #{index + 1}/#{total_batches}: #{error.message}")
        choice = UI.select('Choose action:', ['Skip this batch', 'Retry batch', 'Abort translation'])

        case choice
        when 'Skip this batch'
          UI.important("⏭️ Skipping batch #{index + 1}")
          :skip
        when 'Retry batch'
          UI.message("🔄 Retrying batch #{index + 1}")
          :retry
        when 'Abort translation'
          UI.user_error!('❌ Translation aborted by user')
        end
      end

      def self.update_xcstrings_file(xcstrings_path, xcstrings_data, target_language, translated_strings)
        UI.message("📝 Updating xcstrings file with #{translated_strings.size} translations...")

        # Update the JSON structure
        translated_strings.each do |string_key, translated_text|
          localization = xcstrings_data.dig('strings', string_key, 'localizations', target_language, 'stringUnit')
          next unless localization

          localization['value'] = translated_text
          localization['state'] = 'translated'
        end

        # Write updated JSON back to file
        File.write(xcstrings_path, JSON.pretty_generate(xcstrings_data))
        UI.success('💾 Updated xcstrings file')
      end

      def self.validate_json_file(xcstrings_path)
        JSON.parse(File.read(xcstrings_path))
        UI.success('✅ Updated xcstrings file is valid JSON')
      rescue JSON::ParserError => e
        UI.user_error!("❌ Generated xcstrings file is invalid JSON: #{e.message}")
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        'Automatically translate untranslated strings in Localizable.xcstrings using DeepL API'
      end

      def self.details
        'This action finds your Localizable.xcstrings file, analyzes translation status for each language, ' \
          'and uses DeepL API to translate missing strings. It supports progress tracking, formality options, ' \
          'and provides comprehensive error handling with user choices for recovery.'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :api_token,
            env_name: 'DEEPL_AUTH_KEY',
            description: 'DeepL API authentication key',
            sensitive: true,
            verify_block: proc do |value|
              UI.user_error!('DeepL API key required. Get one at: https://www.deepl.com/pro#developer') if value.to_s.empty?
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :xcstrings_path,
            description: 'Path to Localizable.xcstrings file (auto-detected if not provided)',
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :target_language,
            description: 'Target language code (e.g., "de", "fr", "es") - will prompt if not provided',
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :batch_size,
            description: 'Number of strings to translate per API call',
            type: Integer,
            default_value: 20,
            verify_block: proc do |value|
              UI.user_error!('Batch size must be between 1 and 50') unless (1..50).cover?(value)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :free_api,
            description: 'Use DeepL Free API endpoint instead of Pro',
            type: Boolean,
            default_value: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :formality,
            description: 'Translation formality (auto-detected if language supports it): default, more, less, prefer_more, prefer_less',
            optional: true,
            verify_block: proc do |value|
              if value
                valid_options = %w[default more less prefer_more prefer_less]
                UI.user_error!("Invalid formality. Use: #{valid_options.join(', ')}") unless valid_options.include?(value)
              end
            end
          )
        ]
      end

      def self.output
        [
          ['TRANSLATE_WITH_DEEPL_TRANSLATED_COUNT', 'Number of strings that were translated'],
          ['TRANSLATE_WITH_DEEPL_TARGET_LANGUAGE', 'The target language that was translated'],
          ['TRANSLATE_WITH_DEEPL_BACKUP_FILE', 'Path to the backup file created before translation']
        ]
      end

      def self.return_value
        'Number of strings that were translated'
      end

      def self.authors
        ['Your GitHub/Twitter Name']
      end

      def self.supported?(platform)
        platform == :ios
      end

      def self.example_code
        [
          'translate_with_deepl',
          'translate_with_deepl(target_language: "de")',
          'translate_with_deepl(target_language: "fr", formality: "more")',
          'translate_with_deepl(xcstrings_path: "./MyApp/Localizable.xcstrings", free_api: true)'
        ]
      end

      def self.category
        :misc
      end
    end
  end
end
