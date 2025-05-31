# frozen_string_literal: true

module FastlaneCore
  class UI
    unless respond_to?(:select)
      def self.select(message, options)
        # Fallback implementation for testing
        puts "#{message} (#{options.join(', ')})"
        options.first
      end
    end
  end
end

module Fastlane
  module Helper
    class TranslationErrorHandler
      def self.handle_rate_limit_error(_batch, batch_index, total_batches)
        options = ['Wait 60s and retry', 'Skip this batch', 'Abort translation', '❌ Quit']
        choice = UI.select("⚠️ Rate limit exceeded for batch #{batch_index + 1}/#{total_batches}",
                           options)

        case choice
        when 'Wait 60s and retry'
          UI.message('⏳ Waiting 60 seconds...')
          sleep(60)
          :retry
        when 'Skip this batch'
          UI.important("⏭️ Skipping batch #{batch_index + 1}")
          :skip
        when 'Abort translation'
          UI.user_error!('❌ Translation aborted by user')
        when '❌ Quit'
          :quit
        end
      end

      def self.handle_translation_error(error, _batch, batch_index, total_batches)
        UI.error("❌ Translation error for batch #{batch_index + 1}/#{total_batches}: #{error.message}")
        options = ['Skip this batch', 'Retry batch', 'Abort translation', '❌ Quit']
        choice = UI.select('Choose action:', options)

        case choice
        when 'Skip this batch'
          UI.important("⏭️ Skipping batch #{batch_index + 1}")
          :skip
        when 'Retry batch'
          UI.message("🔄 Retrying batch #{batch_index + 1}")
          :retry
        when 'Abort translation'
          UI.user_error!('❌ Translation aborted by user')
        when '❌ Quit'
          :quit
        end
      end

      def self.handle_batch_result(action, retry_count, max_retries)
        case action
        when :retry
          return :retry if retry_count < max_retries

          UI.error("❌ Max retries (#{max_retries}) exceeded")
          :skip
        when :skip
          :skip
        when :quit
          :quit
        else
          :continue
        end
      end
    end
  end
end
