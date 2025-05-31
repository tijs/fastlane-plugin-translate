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
        # Setup and validation
        setup_deepl_client(params)
        xcstrings_path = find_xcstrings_file(params[:xcstrings_path])

        backup_file = create_backup(xcstrings_path)

        # Parse xcstrings file
        xcstrings_data = JSON.parse(File.read(xcstrings_path))
        source_language = xcstrings_data['sourceLanguage']
        available_languages = extract_available_languages(xcstrings_data)

        # Filter languages supported by DeepL
        supported_languages = Helper::DeeplLanguageMapperHelper.supported_languages_from_list(available_languages)
        unsupported_languages = Helper::DeeplLanguageMapperHelper.unsupported_languages(available_languages)

        UI.important("⚠️  Languages not supported by DeepL: #{unsupported_languages.map { |l| "#{Helper::LanguageRegistryHelper.language_name(l)} (#{l})" }.join(', ')}") if unsupported_languages.any?

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
        UI.message("📊 Translated #{translated_count} strings for #{Helper::LanguageRegistryHelper.language_name(target_language)} (#{target_language})")
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
          lang_name = Helper::LanguageRegistryHelper.language_name(lang_code)
          stats = language_stats[lang_code]
          percentage = ((stats[:translated].to_f / stats[:total]) * 100).round(1)

          display_name = "#{lang_name} (#{lang_code}): #{percentage}% translated (#{stats[:untranslated]} remaining"
          display_name += ", #{stats[:skipped_dont_translate]} don't translate" if (stats[:skipped_dont_translate]).positive?
          display_name += ')'

          # Add formality indicator
          display_name += ' [supports formality]' if Helper::DeeplLanguageMapperHelper.supports_formality?(lang_code)

          { display: display_name, code: lang_code, stats: }
        end

        # Sort by most untranslated first (prioritize languages that need work)
        language_options.sort_by! { |opt| -opt[:stats][:untranslated] }

        # Show all languages with their translation status
        UI.message('📋 Available languages for translation:')

        # Display numbered list
        language_options.each_with_index do |option, index|
          UI.message("  #{index + 1}. #{option[:display]}")
        end

        # Force interactive mode and ensure we wait for user input
        $stdout.flush
        $stderr.flush

        # Use a loop to ensure we get valid input
        loop do
          choice = UI.input("Choose target language (1-#{language_options.count}): ").strip

          # Validate numeric input
          if choice.match?(/^\d+$/)
            choice_num = choice.to_i
            if choice_num >= 1 && choice_num <= language_options.count
              selected_option = language_options[choice_num - 1]
              UI.message("✅ Selected: #{selected_option[:display]}")
              return selected_option[:code]
            end
          end

          UI.error("❌ Invalid selection '#{choice}'. Please enter a number between 1 and #{language_options.count}.")
        rescue Interrupt
          UI.user_error!('👋 Translation cancelled by user')
        end
      end

      def self.calculate_translation_stats(xcstrings_data, languages)
        stats = {}

        languages.each do |lang_code|
          total = 0
          translated = 0
          skipped_dont_translate = 0

          xcstrings_data['strings'].each do |string_key, string_data|
            # Skip empty string keys as they're usually not real translatable content
            next if string_key.empty?

            # Skip strings marked as "Don't translate" from statistics
            if string_data['shouldTranslate'] == false
              skipped_dont_translate += 1
              next
            end

            # Check if this string has any localizations at all
            if !string_data['localizations'] || string_data['localizations'].empty?
              # String has no localizations - count as untranslated for this language
              total += 1
              next
            end

            # Check if this string has a localization for the target language
            localization = string_data.dig('localizations', lang_code, 'stringUnit')
            unless localization
              # String exists but has no localization for this specific language - count as untranslated
              total += 1
              next
            end

            total += 1

            # Count as translated ONLY if state is 'translated' AND has non-empty value
            # Strings with state 'new', 'needs_review', or empty values are untranslated
            if localization['state'] == 'translated' &&
               localization['value'] && !localization['value'].strip.empty?
              translated += 1
            end
          end

          stats[lang_code] = {
            total:,
            translated:,
            untranslated: total - translated,
            skipped_dont_translate:
          }
        end

        stats
      end

      def self.detect_and_ask_formality(target_language, formality_param)
        return formality_param if formality_param
        return nil unless Helper::DeeplLanguageMapperHelper.supports_formality?(target_language)

        lang_name = Helper::LanguageRegistryHelper.language_name(target_language)
        options = [
          { display: 'default (no formality preference)', value: nil },
          { display: 'more (formal)', value: 'more' },
          { display: 'less (informal)', value: 'less' },
          { display: 'prefer_more (formal if possible)', value: 'prefer_more' },
          { display: 'prefer_less (informal if possible)', value: 'prefer_less' }
        ]

        # Display numbered list
        UI.message("🎭 #{lang_name} supports formality options. Choose style:")
        options.each_with_index do |option, index|
          UI.message("  #{index + 1}. #{option[:display]}")
        end

        # Force interactive mode and ensure we wait for user input
        $stdout.flush
        $stderr.flush

        # Use a loop to ensure we get valid input
        loop do
          choice = UI.input("Choose formality style (1-#{options.count}): ").strip

          # Validate numeric input
          if choice.match?(/^\d+$/)
            choice_num = choice.to_i
            if choice_num >= 1 && choice_num <= options.count
              selected_option = options[choice_num - 1]
              UI.message("✅ Selected: #{selected_option[:display]}")
              return selected_option[:value]
            end
          end

          UI.error("❌ Invalid selection '#{choice}'. Please enter a number between 1 and #{options.count}.")
        rescue Interrupt
          UI.user_error!('👋 Translation cancelled by user')
        end
      end

      def self.translate_language(xcstrings_data, xcstrings_path, source_language, target_language, formality, params)
        # Validate DeepL support
        UI.user_error!("❌ Language '#{target_language}' is not supported by DeepL") unless Helper::DeeplLanguageMapperHelper.supported?(target_language)

        # Get DeepL language codes
        deepl_source = Helper::DeeplLanguageMapperHelper.get_source_language(source_language)
        deepl_target = Helper::DeeplLanguageMapperHelper.get_target_language(target_language)

        UI.message("🔄 Translating from #{deepl_source} to #{deepl_target}")

        # Progress setup
        progress = Helper::TranslationProgressHelper.create_progress_tracker(xcstrings_path, target_language)

        if progress.has_progress?
          summary = progress.progress_summary
          UI.message("📈 Found existing progress: #{summary[:translated_count]} strings translated")

          # Display numbered options
          UI.message('Continue from where you left off?')
          UI.message('  1. Yes, continue')
          UI.message('  2. No, start fresh')

          # Force interactive mode and ensure we wait for user input
          $stdout.flush
          $stderr.flush

          # Use a loop to ensure we get valid input
          loop do
            choice = UI.input('Choose option (1-2): ').strip

            case choice
            when '1'
              UI.message('✅ Continuing from existing progress')
              break
            when '2'
              UI.message('✅ Starting fresh')
              progress.cleanup
              break
            else
              UI.error("❌ Invalid selection '#{choice}'. Please enter 1 or 2.")
            end
          rescue Interrupt
            UI.user_error!('👋 Translation cancelled by user')
          end
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

        # Debug: Show what strings we're about to translate
        UI.message('🔍 Debug: Strings to translate:')
        untranslated_strings.each do |string_key, data|
          UI.message("  - \"#{string_key}\" -> source: \"#{data['source_text']}\"")
        end

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

          # Skip strings marked as "Don't translate" in Xcode
          if string_data['shouldTranslate'] == false
            UI.message("⏭️ Skipping string marked as 'Don't translate': \"#{string_key}\"")
            next
          end

          # Skip if already translated in progress
          next if already_translated[string_key]

          # Check if this string has any localizations at all
          if !string_data['localizations'] || string_data['localizations'].empty?
            # String has no localizations - it's completely new and needs translation
            # Use the string key itself as the source text since there's no source localization
            untranslated[string_key] = {
              'source_text' => string_key,
              'context' => extract_string_context(string_key, string_data)
            }
            next
          end

          # Check if target language has a localization
          localization = string_data.dig('localizations', target_language, 'stringUnit')
          unless localization
            # String exists but has no localization for target language
            # Get source text from source language or use string key as fallback
            source_text = string_data.dig('localizations', source_language, 'stringUnit', 'value')
            source_text = string_key if source_text.nil? || source_text.strip.empty?

            untranslated[string_key] = {
              'source_text' => source_text,
              'context' => extract_string_context(string_key, string_data)
            }
            next
          end

          # Check if NOT fully translated (inverse of the translation stats logic)
          # A string is considered translated only if: state == 'translated' AND has non-empty value
          is_fully_translated = localization['state'] == 'translated' &&
                                localization['value'] && !localization['value'].strip.empty?
          next if is_fully_translated

          # Get source text from source language
          source_text = string_data.dig('localizations', source_language, 'stringUnit', 'value')
          # Use string key as fallback if no source text available
          source_text = string_key if source_text.nil? || source_text.strip.empty?

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

          retry_count = 0
          max_retries = 3

          begin
            # Process the batch using the helper
            result = Helper::BatchTranslationProcessor.process_batch(
              batch, source_lang, target_lang, formality, progress
            )

            total_translated += result[:translated_count]

            success_msg = "✅ Batch #{index + 1} completed (#{result[:translated_count]} strings translated"
            success_msg += ", #{result[:skipped_count]} empty translations skipped" if result[:skipped_count].positive?
            success_msg += ')'
            UI.success(success_msg)
          rescue DeepL::Exceptions::AuthorizationFailed
            UI.user_error!('❌ Invalid DeepL API key')
          rescue DeepL::Exceptions::QuotaExceeded
            UI.user_error!('❌ DeepL quota exceeded. Upgrade your plan or wait for reset.')
          rescue DeepL::Exceptions::LimitExceeded
            action = Helper::TranslationErrorHandler.handle_rate_limit_error(batch, index, batches.count)
            result = Helper::TranslationErrorHandler.handle_batch_result(action, retry_count, max_retries)

            case result
            when :retry
              retry_count += 1
              retry
            when :skip
              next
            end
          rescue StandardError => e
            action = Helper::TranslationErrorHandler.handle_translation_error(e, batch, index, batches.count)
            result = Helper::TranslationErrorHandler.handle_batch_result(action, retry_count, max_retries)

            case result
            when :retry
              retry_count += 1
              retry
            when :skip
              next
            end
          end
        end

        total_translated
      end

      def self.update_xcstrings_file(xcstrings_path, xcstrings_data, target_language, translated_strings)
        UI.message("📝 Updating xcstrings file with #{translated_strings.size} translations...")

        # Update the JSON structure
        actually_updated = 0
        empty_translations = 0
        translated_strings.each do |string_key, translated_text|
          # Ensure the string exists in the xcstrings structure
          xcstrings_data['strings'][string_key] ||= {}
          string_data = xcstrings_data['strings'][string_key]

          # Ensure localizations structure exists
          string_data['localizations'] ||= {}

          # Ensure target language localization exists
          string_data['localizations'][target_language] ||= {}

          # Ensure stringUnit exists
          string_data['localizations'][target_language]['stringUnit'] ||= {}

          localization = string_data['localizations'][target_language]['stringUnit']

          # Double-check: only mark as translated if we have actual content
          if translated_text && !translated_text.strip.empty?
            localization['value'] = translated_text
            localization['state'] = 'translated'
            actually_updated += 1
            UI.message("✅ Updated \"#{string_key}\" -> \"#{translated_text}\"")
          else
            # Keep as 'new' if translation is empty
            localization['value'] = translated_text || ''
            localization['state'] = 'new'
            empty_translations += 1
            UI.important("⚠️ Empty translation for \"#{string_key}\" (received: \"#{translated_text || 'nil'}\")")
          end
        end

        # Write updated JSON back to file
        File.write(xcstrings_path, JSON.pretty_generate(xcstrings_data))
        UI.success("💾 Updated xcstrings file (#{actually_updated} marked as translated, #{empty_translations} empty)")
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
            default_value: 50,
            verify_block: proc do |value|
              UI.user_error!('Batch size must be between 1 and 50') unless (1..50).cover?(value)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :free_api,
            description: 'Use DeepL Free API endpoint instead of Pro',
            is_string: false,
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

      def self.is_supported?(platform)
        platform == :ios
      end
      # rubocop:enable Naming/PredicateName

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
