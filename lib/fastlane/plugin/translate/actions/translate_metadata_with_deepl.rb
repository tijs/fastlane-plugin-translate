# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'deepl'

module Fastlane
  module Actions
    module SharedValues
      TRANSLATE_METADATA_WITH_DEEPL_TRANSLATED_COUNT = :TRANSLATE_METADATA_WITH_DEEPL_TRANSLATED_COUNT
      TRANSLATE_METADATA_WITH_DEEPL_TARGET_LANGUAGES = :TRANSLATE_METADATA_WITH_DEEPL_TARGET_LANGUAGES
      TRANSLATE_METADATA_WITH_DEEPL_BACKUP_FILE = :TRANSLATE_METADATA_WITH_DEEPL_BACKUP_FILE
    end

    class TranslateMetadataWithDeeplAction < Action
      def self.run(params)
        # Setup and validation
        setup_deepl_client(params)

        metadata_path = params[:metadata_path]
        source_locale = params[:source_locale]
        file_name = params[:file_name]

        # Validate source file exists
        source_file_path = File.join(metadata_path, source_locale, file_name)
        UI.user_error!("❌ Source file not found: #{source_file_path}") unless File.exist?(source_file_path)

        # Read source content
        source_content = File.read(source_file_path).strip
        UI.user_error!("❌ Source file is empty: #{source_file_path}") if source_content.empty?

        # Create backup
        backup_file = create_backup(source_file_path)

        # Detect available target languages
        target_languages = detect_target_languages(metadata_path, source_locale, params[:target_languages])

        # Filter by DeepL support
        supported_languages = Helper::DeeplLanguageMapperHelper.supported_languages_from_list(target_languages)
        unsupported_languages = Helper::DeeplLanguageMapperHelper.unsupported_languages(target_languages)

        UI.important("⚠️  Languages not supported by DeepL: #{unsupported_languages.map { |l| "#{Helper::LanguageRegistryHelper.language_name(l)} (#{l})" }.join(', ')}") if unsupported_languages.any?

        UI.user_error!('❌ No DeepL-supported languages found') if supported_languages.empty?

        UI.message("📋 Translating #{file_name} from #{source_locale} to #{supported_languages.size} languages:")
        supported_languages.each { |lang| UI.message("  • #{Helper::LanguageRegistryHelper.language_name(lang)} (#{lang})") }

        # Translate to each target language
        total_translated = 0
        successful_languages = []

        supported_languages.each do |target_language|
          UI.message("🔄 Translating to #{Helper::LanguageRegistryHelper.language_name(target_language)} (#{target_language})...")

          begin
            # Determine formality for this language
            formality = determine_formality(target_language, params[:formality])

            # Translate content
            translated_content = translate_content(source_content, source_locale, target_language, formality)

            # Write to target file
            target_file_path = File.join(metadata_path, map_to_metadata_directory(target_language), file_name)
            ensure_directory_exists(File.dirname(target_file_path))
            File.write(target_file_path, translated_content)

            UI.success("✅ #{target_language}: Translation completed")
            total_translated += 1
            successful_languages << target_language
          rescue StandardError => e
            UI.error("❌ #{target_language}: Translation failed - #{e.message}")
          end
        end

        # Set shared values
        Actions.lane_context[SharedValues::TRANSLATE_METADATA_WITH_DEEPL_TRANSLATED_COUNT] = total_translated
        Actions.lane_context[SharedValues::TRANSLATE_METADATA_WITH_DEEPL_TARGET_LANGUAGES] = successful_languages
        Actions.lane_context[SharedValues::TRANSLATE_METADATA_WITH_DEEPL_BACKUP_FILE] = backup_file

        UI.success('🎉 Metadata translation completed!')
        UI.message("📊 Successfully translated #{file_name} for #{total_translated} languages")
        UI.message("📄 Backup saved: #{backup_file}")
        UI.message('🗑️  You can delete the backup after verifying results')

        total_translated
      end

      def self.setup_deepl_client(params)
        # If free_api is explicitly set, use that configuration
        if params[:free_api] != nil
          DeepL.configure do |config|
            config.auth_key = params[:api_token]
            config.host = params[:free_api] ? 'https://api-free.deepl.com' : 'https://api.deepl.com'
          end

          begin
            DeepL.usage
            api_type = params[:free_api] ? 'Free' : 'Pro'
            UI.success("✅ DeepL API key validated (#{api_type} API)")
            return
          rescue DeepL::Exceptions::AuthorizationFailed
            UI.user_error!('❌ Invalid DeepL API key. Get one at: https://www.deepl.com/pro#developer')
          rescue StandardError => e
            UI.user_error!("❌ DeepL API connection failed: #{e.message}")
          end
        end

        # Auto-detect: try Pro API first, then Free API
        endpoints = [
          { host: 'https://api.deepl.com', name: 'Pro' },
          { host: 'https://api-free.deepl.com', name: 'Free' }
        ]

        endpoints.each_with_index do |endpoint, index|
          DeepL.configure do |config|
            config.auth_key = params[:api_token]
            config.host = endpoint[:host]
          end

          begin
            DeepL.usage
            UI.success("✅ DeepL API key validated (#{endpoint[:name]} API)")
            UI.message("💡 Tip: You can skip auto-detection by setting free_api: #{endpoint[:name] == 'Free'}") if index > 0
            return
          rescue DeepL::Exceptions::AuthorizationFailed
            # Try next endpoint if this one fails
            next if index < endpoints.length - 1
            # Both endpoints failed
            UI.user_error!('❌ Invalid DeepL API key. Get one at: https://www.deepl.com/pro#developer')
          rescue StandardError => e
            UI.user_error!("❌ DeepL API connection failed: #{e.message}")
          end
        end
      end

      def self.create_backup(source_file_path)
        timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
        backup_path = "#{source_file_path}.backup_#{timestamp}"
        FileUtils.cp(source_file_path, backup_path)
        UI.message("💾 Backup created: #{backup_path}")
        backup_path
      end

      def self.detect_target_languages(metadata_path, source_locale, specified_languages)
        if specified_languages && !specified_languages.empty?
          UI.message("🎯 Using specified target languages: #{specified_languages.join(', ')}")
          return specified_languages
        end

        # Auto-detect from existing metadata directories
        UI.message('🔍 Auto-detecting target languages from metadata directories...')

        detected_languages = []
        Dir.glob(File.join(metadata_path, '*')).each do |dir|
          next unless File.directory?(dir)

          locale = File.basename(dir)
          next if locale == source_locale # Skip source locale
          next if locale == 'default' # Skip special directories
          next if locale == 'review_information'

          # Map metadata directory names to DeepL-compatible language codes
          deepl_language = map_metadata_directory_to_language(locale)
          detected_languages << deepl_language
        end

        UI.message("📁 Found metadata directories for: #{detected_languages.join(', ')}")
        detected_languages
      end

      def self.map_metadata_directory_to_language(metadata_dir)
        # Map App Store metadata directory names to DeepL-compatible language codes
        case metadata_dir
        when 'de-DE'
          'de' # German metadata directory -> de for DeepL
        when 'es-ES'
          'es' # Spanish (Spain) metadata directory -> es for DeepL
        when 'fr-FR'
          'fr' # French metadata directory -> fr for DeepL
        when 'nl-NL'
          'nl' # Dutch metadata directory -> nl for DeepL
        when 'no'
          'nb' # Norwegian metadata directory -> nb (Bokmål) for DeepL
        else
          metadata_dir # Direct mapping for most languages
        end
      end

      def self.determine_formality(target_language, formality_param)
        return formality_param if formality_param

        if Helper::DeeplLanguageMapperHelper.supports_formality?(target_language)
          UI.message("🎭 #{Helper::LanguageRegistryHelper.language_name(target_language)} supports formality options")
          return 'prefer_more' # Default to more formal for App Store metadata
        end

        nil
      end

      def self.translate_content(source_content, source_language, target_language, formality)
        source_lang = Helper::DeeplLanguageMapperHelper.get_source_language(source_language)
        target_lang = Helper::DeeplLanguageMapperHelper.get_target_language(target_language)

        translation_options = {}
        translation_options[:formality] = formality if formality

        # DeepL.translate expects: texts, source_lang, target_lang, options
        result = DeepL.translate([source_content], source_lang, target_lang, translation_options)

        # Handle both single and array responses
        result.is_a?(Array) ? result.first.text : result.text
      rescue StandardError => e
        raise "DeepL translation failed: #{e.message}"
      end

      def self.map_to_metadata_directory(language_code)
        # Map DeepL language codes back to App Store metadata directory names
        case language_code
        when 'nb'
          'no' # Norwegian Bokmål -> no
        when 'de'
          'de-DE' # German -> de-DE
        when 'es'
          'es-ES' # Spanish -> es-ES
        when 'fr'
          'fr-FR' # French -> fr-FR
        when 'nl'
          'nl-NL' # Dutch -> nl-NL
        else
          language_code # Direct mapping for most languages
        end
      end

      def self.ensure_directory_exists(directory_path)
        FileUtils.mkdir_p(directory_path) unless File.directory?(directory_path)
      end

      def self.description
        'Translate App Store metadata files using DeepL API'
      end

      def self.details
        'This action translates App Store metadata files (like release_notes.txt, description.txt) ' \
          'from a source language to all supported target languages using DeepL API. ' \
          'It automatically detects target languages from existing metadata directories ' \
          'and only translates to languages supported by both App Store and DeepL.'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :api_token,
            env_name: 'DEEPL_AUTH_KEY',
            description: 'DeepL API authentication key',
            sensitive: true,
            default_value: ENV.fetch('DEEPL_AUTH_KEY', nil)
          ),
          FastlaneCore::ConfigItem.new(
            key: :metadata_path,
            description: 'Path to fastlane metadata directory',
            default_value: './fastlane/metadata',
            verify_block: proc do |value|
              UI.user_error!("Metadata directory not found: #{value}") unless File.directory?(value)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :source_locale,
            description: 'Source language locale (e.g., en-US)',
            default_value: 'en-US'
          ),
          FastlaneCore::ConfigItem.new(
            key: :file_name,
            description: 'Metadata file to translate (e.g., release_notes.txt, description.txt)',
            default_value: 'release_notes.txt'
          ),
          FastlaneCore::ConfigItem.new(
            key: :target_languages,
            description: 'Specific target languages to translate to (optional, auto-detects if not specified)',
            type: Array,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :formality,
            description: 'Formality setting for translation (default, more, less, prefer_more, prefer_less)',
            optional: true,
            verify_block: proc do |value|
              valid_options = %w[default more less prefer_more prefer_less]
              UI.user_error!("Invalid formality option. Must be one of: #{valid_options.join(', ')}") unless valid_options.include?(value)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :free_api,
            description: 'Use DeepL Free API endpoint (auto-detects if not specified)',
            type: Boolean,
            optional: true,
            default_value: nil
          )
        ]
      end

      def self.output
        [
          ['TRANSLATE_METADATA_WITH_DEEPL_TRANSLATED_COUNT', 'Number of languages successfully translated'],
          ['TRANSLATE_METADATA_WITH_DEEPL_TARGET_LANGUAGES', 'Array of target language codes that were translated'],
          ['TRANSLATE_METADATA_WITH_DEEPL_BACKUP_FILE', 'Path to the backup file created before translation']
        ]
      end

      def self.return_value
        'Number of languages that were successfully translated'
      end

      def self.authors
        ['tijs']
      end

      def self.is_supported?(platform)
        %i[ios android].include?(platform)
      end

      def self.example_code
        [
          '# Translate release notes to all detected languages',
          'translate_metadata_with_deepl',
          '',
          '# Translate description file with specific settings',
          'translate_metadata_with_deepl(',
          '  file_name: "description.txt",',
          '  source_locale: "en-US",',
          '  formality: "prefer_more"',
          ')',
          '',
          '# Translate only to specific languages',
          'translate_metadata_with_deepl(',
          '  file_name: "release_notes.txt",',
          '  target_languages: ["de", "fr-FR", "es-ES", "ja"]',
          ')'
        ]
      end

      def self.category
        :misc
      end
    end
  end
end
