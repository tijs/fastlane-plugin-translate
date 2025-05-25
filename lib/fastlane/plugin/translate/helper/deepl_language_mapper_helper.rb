# frozen_string_literal: true

require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class DeeplLanguageMapperHelper
      # DeepL API language mappings
      # Based on: https://developers.deepl.com/docs/resources/supported-languages
      DEEPL_MAPPINGS = {
        # iOS language code => { source: DeepL_source_code, target: DeepL_target_code }
        'ar' => { source: 'AR', target: 'AR' },
        'bg' => { source: 'BG', target: 'BG' },
        'cs' => { source: 'CS', target: 'CS' },
        'da' => { source: 'DA', target: 'DA' },
        'de' => { source: 'DE', target: 'DE' },
        'el' => { source: 'EL', target: 'EL' },
        'en' => { source: 'EN', target: 'EN' },
        'en-US' => { source: 'EN', target: 'EN-US' },
        'en-GB' => { source: 'EN', target: 'EN-GB' },
        'en-AU' => { source: 'EN', target: 'EN-GB' }, # DeepL doesn't have AU variant
        'en-CA' => { source: 'EN', target: 'EN-US' }, # DeepL doesn't have CA variant
        'es' => { source: 'ES', target: 'ES' },
        'es-ES' => { source: 'ES', target: 'ES' },
        'es-MX' => { source: 'ES', target: 'ES' }, # DeepL doesn't distinguish ES variants for target
        'et' => { source: 'ET', target: 'ET' },
        'fi' => { source: 'FI', target: 'FI' },
        'fr' => { source: 'FR', target: 'FR' },
        'fr-CA' => { source: 'FR', target: 'FR' },
        'hu' => { source: 'HU', target: 'HU' },
        'id' => { source: 'ID', target: 'ID' },
        'it' => { source: 'IT', target: 'IT' },
        'ja' => { source: 'JA', target: 'JA' },
        'ko' => { source: 'KO', target: 'KO' },
        'lt' => { source: 'LT', target: 'LT' },
        'lv' => { source: 'LV', target: 'LV' },
        'nb' => { source: 'NB', target: 'NB' },
        'nl' => { source: 'NL', target: 'NL' },
        'pl' => { source: 'PL', target: 'PL' },
        'pt' => { source: 'PT', target: 'PT-PT' },
        'pt-BR' => { source: 'PT', target: 'PT-BR' },
        'pt-PT' => { source: 'PT', target: 'PT-PT' },
        'ro' => { source: 'RO', target: 'RO' },
        'ru' => { source: 'RU', target: 'RU' },
        'sk' => { source: 'SK', target: 'SK' },
        'sl' => { source: 'SL', target: 'SL' },
        'sv' => { source: 'SV', target: 'SV' },
        'tr' => { source: 'TR', target: 'TR' },
        'uk' => { source: 'UK', target: 'UK' },
        'zh' => { source: 'ZH', target: 'ZH' },
        'zh-Hans' => { source: 'ZH', target: 'ZH' },
        'zh-Hant' => { source: 'ZH', target: 'ZH-HANT' },
        'zh-HK' => { source: 'ZH', target: 'ZH-HANT' }
      }.freeze

      # Languages that support formality in DeepL
      FORMALITY_SUPPORTED = %w[DE FR IT ES NL PL PT-BR PT-PT JA RU].freeze

      def self.supported?(ios_language_code)
        DEEPL_MAPPINGS.key?(ios_language_code)
      end

      def self.get_source_language(ios_language_code)
        mapping = DEEPL_MAPPINGS[ios_language_code]
        return nil unless mapping

        mapping[:source]
      end

      def self.get_target_language(ios_language_code)
        mapping = DEEPL_MAPPINGS[ios_language_code]
        return nil unless mapping

        mapping[:target]
      end

      def self.supports_formality?(ios_language_code)
        target_lang = get_target_language(ios_language_code)
        return false unless target_lang

        FORMALITY_SUPPORTED.include?(target_lang)
      end

      def self.unsupported_languages(ios_language_codes)
        ios_language_codes.reject { |code| supported?(code) }
      end

      def self.supported_languages_from_list(ios_language_codes)
        ios_language_codes.select { |code| supported?(code) }
      end

      def self.all_supported_languages
        DEEPL_MAPPINGS.keys
      end
    end
  end
end
