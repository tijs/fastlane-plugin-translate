# frozen_string_literal: true

require 'deepl'
require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class BatchTranslationProcessor
      def self.process_batch(batch, source_lang, target_lang, formality, progress)
        # Prepare batch for DeepL API
        texts_to_translate = batch.map { |_, data| data['source_text'] }

        UI.message('🔍 Debug: Sending to DeepL:')
        texts_to_translate.each_with_index do |text, i|
          UI.message("  #{i + 1}. \"#{text}\"")
        end

        # Build translation options
        translation_options = build_translation_options(formality, batch)

        # Call DeepL API
        translations = DeepL.translate(texts_to_translate, source_lang, target_lang, translation_options)

        UI.message('🔍 Debug: DeepL returned:')
        if translations.is_a?(Array)
          translations.each_with_index do |trans, i|
            UI.message("  #{i + 1}. \"#{trans.text}\"")
          end
        else
          UI.message("  Single result: \"#{translations.text}\"")
        end

        # Process and save translations
        save_batch_translations(batch, translations, progress)
      end

      def self.build_translation_options(formality, batch)
        translation_options = {}
        translation_options[:formality] = formality if formality

        # Get context from first item if available (DeepL applies to all)
        first_context = batch.first&.last&.dig('context')
        translation_options[:context] = first_context if first_context

        translation_options
      end

      def self.save_batch_translations(batch, translations, progress)
        translated_batch = {}
        skipped_empty = 0

        batch.each_with_index do |(string_key, _), text_index|
          translated_text = translations.is_a?(Array) ? translations[text_index].text : translations.text

          # Save all translations, including empty ones - let the update logic handle them
          translated_batch[string_key] = translated_text || ''

          # Count empty translations for reporting
          if !translated_text || translated_text.strip.empty?
            skipped_empty += 1
            UI.important("⚠️ DeepL returned empty translation for: \"#{string_key}\"")
          end
        end

        progress.save_translated_strings(translated_batch)

        {
          translated_count: translated_batch.size - skipped_empty, # Only count non-empty as "translated"
          skipped_count: skipped_empty
        }
      end

      private_class_method :build_translation_options, :save_batch_translations
    end
  end
end
