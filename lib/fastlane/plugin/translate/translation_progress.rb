require 'json'
require 'time'

module Fastlane
  module Translate
    class TranslationProgress
      def initialize(xcstrings_path, target_language)
        @progress_file = "#{xcstrings_path}.translation_progress_#{target_language}.json"
      end

      def save_translated_strings(translated_strings)
        progress = load_progress
        progress['translated_strings'].merge!(translated_strings)
        progress['last_updated'] = Time.now.iso8601
        progress['total_translated'] = progress['translated_strings'].size
        
        File.write(@progress_file, JSON.pretty_generate(progress))
        UI.verbose("💾 Saved progress: #{translated_strings.size} new translations")
      end

      def load_progress
        return default_progress unless File.exist?(@progress_file)
        
        begin
          JSON.parse(File.read(@progress_file))
        rescue JSON::ParserError => e
          UI.important("⚠️ Corrupted progress file, starting fresh: #{e.message}")
          default_progress
        end
      end

      def has_progress?
        File.exist?(@progress_file) && load_progress['translated_strings'].any?
      end

      def progress_summary
        progress = load_progress
        {
          translated_count: progress['translated_strings'].size,
          last_updated: progress['last_updated']
        }
      end

      def cleanup
        if File.exist?(@progress_file)
          File.delete(@progress_file)
          UI.verbose("🗑️ Cleaned up progress file")
        end
      end

      def get_translated_strings
        load_progress['translated_strings']
      end

      private

      def default_progress
        {
          'translated_strings' => {},
          'last_updated' => nil,
          'total_translated' => 0
        }
      end
    end
  end
end 