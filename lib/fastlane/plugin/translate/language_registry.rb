module Fastlane
  module Translate
    class LanguageRegistry
      # Complete list based on Apple's App Store localizations
      # https://developer.apple.com/help/app-store-connect/reference/app-store-localizations/
      APPLE_LANGUAGES = {
        # Language code => { name, regional_variants }
        'ar' => { name: 'Arabic', variants: [] },
        'ca' => { name: 'Catalan', variants: [] },
        'hr' => { name: 'Croatian', variants: [] },
        'cs' => { name: 'Czech', variants: [] },
        'da' => { name: 'Danish', variants: [] },
        'nl' => { name: 'Dutch', variants: [] },
        'en' => { name: 'English', variants: ['en-US', 'en-GB', 'en-AU', 'en-CA'] },
        'en-US' => { name: 'English (United States)', variants: [] },
        'en-GB' => { name: 'English (United Kingdom)', variants: [] },
        'en-AU' => { name: 'English (Australia)', variants: [] },
        'en-CA' => { name: 'English (Canada)', variants: [] },
        'fi' => { name: 'Finnish', variants: [] },
        'fr' => { name: 'French', variants: ['fr-CA'] },
        'fr-CA' => { name: 'French (Canada)', variants: [] },
        'de' => { name: 'German', variants: [] },
        'el' => { name: 'Greek', variants: [] },
        'he' => { name: 'Hebrew', variants: [] },
        'hi' => { name: 'Hindi', variants: [] },
        'hu' => { name: 'Hungarian', variants: [] },
        'id' => { name: 'Indonesian', variants: [] },
        'it' => { name: 'Italian', variants: [] },
        'ja' => { name: 'Japanese', variants: [] },
        'ko' => { name: 'Korean', variants: [] },
        'ms' => { name: 'Malay', variants: [] },
        'nb' => { name: 'Norwegian Bokmål', variants: [] },
        'pl' => { name: 'Polish', variants: [] },
        'pt' => { name: 'Portuguese', variants: ['pt-BR', 'pt-PT'] },
        'pt-BR' => { name: 'Portuguese (Brazil)', variants: [] },
        'pt-PT' => { name: 'Portuguese (Portugal)', variants: [] },
        'ro' => { name: 'Romanian', variants: [] },
        'ru' => { name: 'Russian', variants: [] },
        'sk' => { name: 'Slovak', variants: [] },
        'es' => { name: 'Spanish', variants: ['es-MX', 'es-ES'] },
        'es-MX' => { name: 'Spanish (Mexico)', variants: [] },
        'es-ES' => { name: 'Spanish (Spain)', variants: [] },
        'sv' => { name: 'Swedish', variants: [] },
        'th' => { name: 'Thai', variants: [] },
        'tr' => { name: 'Turkish', variants: [] },
        'uk' => { name: 'Ukrainian', variants: [] },
        'vi' => { name: 'Vietnamese', variants: [] },
        'zh' => { name: 'Chinese', variants: ['zh-Hans', 'zh-Hant', 'zh-HK'] },
        'zh-Hans' => { name: 'Chinese (Simplified)', variants: [] },
        'zh-Hant' => { name: 'Chinese (Traditional)', variants: [] },
        'zh-HK' => { name: 'Chinese (Hong Kong)', variants: [] }
      }.freeze

      def self.supported_languages
        APPLE_LANGUAGES.keys
      end

      def self.language_name(code)
        APPLE_LANGUAGES.dig(code, :name) || code
      end

      def self.has_variants?(code)
        APPLE_LANGUAGES.dig(code, :variants)&.any? || false
      end

      def self.get_variants(code)
        APPLE_LANGUAGES.dig(code, :variants) || []
      end

      def self.valid_language?(code)
        APPLE_LANGUAGES.key?(code)
      end
    end
  end
end 