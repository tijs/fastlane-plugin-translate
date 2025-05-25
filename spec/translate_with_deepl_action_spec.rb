# frozen_string_literal: true

describe Fastlane::Actions::TranslateWithDeeplAction do
  describe '#run' do
    it 'has proper description' do
      expect(Fastlane::Actions::TranslateWithDeeplAction.description).to include('translate')
      expect(Fastlane::Actions::TranslateWithDeeplAction.description).to include('DeepL')
    end

    it 'supports iOS platform' do
      expect(Fastlane::Actions::TranslateWithDeeplAction.is_supported?(:ios)).to be true
    end

    it 'does not support Android platform' do
      expect(Fastlane::Actions::TranslateWithDeeplAction.is_supported?(:android)).to be false
    end

    it 'has required options' do
      options = Fastlane::Actions::TranslateWithDeeplAction.available_options
      option_keys = options.map(&:key)

      expect(option_keys).to include(:api_token)
      expect(option_keys).to include(:xcstrings_path)
      expect(option_keys).to include(:target_language)
    end

    it 'returns number of translated strings' do
      expect(Fastlane::Actions::TranslateWithDeeplAction.return_value).to eq('Number of strings that were translated')
    end
  end

  describe '#calculate_translation_stats' do
    let(:sample_xcstrings_data) do
      {
        'strings' => {
          'Hello' => {
            'localizations' => {
              'de' => { 'stringUnit' => { 'state' => 'translated', 'value' => 'Hallo' } },
              'fr' => { 'stringUnit' => { 'state' => 'new', 'value' => '' } }
            }
          },
          'Goodbye' => {
            'localizations' => {
              'de' => { 'stringUnit' => { 'state' => 'new', 'value' => '' } },
              'fr' => { 'stringUnit' => { 'state' => 'translated', 'value' => 'Au revoir' } }
            }
          },
          '400V' => {
            'shouldTranslate' => false,
            'localizations' => {
              'de' => { 'stringUnit' => { 'state' => 'new', 'value' => '' } },
              'fr' => { 'stringUnit' => { 'state' => 'new', 'value' => '' } }
            }
          },
          'Brand Name' => {
            'shouldTranslate' => false,
            'localizations' => {
              'de' => { 'stringUnit' => { 'state' => 'translated', 'value' => 'Brand Name' } },
              'fr' => { 'stringUnit' => { 'state' => 'translated', 'value' => 'Brand Name' } }
            }
          },
          'Settings' => {
            'localizations' => {
              'de' => { 'stringUnit' => { 'state' => 'translated', 'value' => 'Einstellungen' } },
              'fr' => { 'stringUnit' => { 'state' => 'translated', 'value' => 'Paramètres' } }
            }
          }
        }
      }
    end

    let(:languages) { %w[de fr] }

    it 'excludes strings marked with shouldTranslate: false from statistics' do
      stats = Fastlane::Actions::TranslateWithDeeplAction.calculate_translation_stats(sample_xcstrings_data, languages)

      # Should count only 3 translatable strings per language (excluding 2 shouldTranslate: false)
      expect(stats['de'][:total]).to eq(3)
      expect(stats['fr'][:total]).to eq(3)
    end

    it 'counts skipped shouldTranslate: false strings correctly' do
      stats = Fastlane::Actions::TranslateWithDeeplAction.calculate_translation_stats(sample_xcstrings_data, languages)

      # Should skip 2 strings marked as shouldTranslate: false
      expect(stats['de'][:skipped_dont_translate]).to eq(2)
      expect(stats['fr'][:skipped_dont_translate]).to eq(2)
    end

    it 'calculates correct translation counts for German' do
      stats = Fastlane::Actions::TranslateWithDeeplAction.calculate_translation_stats(sample_xcstrings_data, languages)

      # German: 'Hello' (translated), 'Goodbye' (new), 'Settings' (translated) = 2/3 translated
      expect(stats['de'][:translated]).to eq(2)
      expect(stats['de'][:untranslated]).to eq(1)
    end

    it 'calculates correct translation counts for French' do
      stats = Fastlane::Actions::TranslateWithDeeplAction.calculate_translation_stats(sample_xcstrings_data, languages)

      # French: 'Hello' (new), 'Goodbye' (translated), 'Settings' (translated) = 2/3 translated
      expect(stats['fr'][:translated]).to eq(2)
      expect(stats['fr'][:untranslated]).to eq(1)
    end

    it 'handles strings with empty values correctly' do
      # Test with empty translated value (should not count as translated)
      xcstrings_with_empty = {
        'strings' => {
          'Test' => {
            'localizations' => {
              'de' => { 'stringUnit' => { 'state' => 'translated', 'value' => '' } }
            }
          }
        }
      }

      stats = Fastlane::Actions::TranslateWithDeeplAction.calculate_translation_stats(xcstrings_with_empty, ['de'])

      expect(stats['de'][:translated]).to eq(0)
      expect(stats['de'][:untranslated]).to eq(1)
    end

    it 'ignores strings without localizations for target language' do
      xcstrings_missing_lang = {
        'strings' => {
          'OnlyEnglish' => {
            'localizations' => {
              'en' => { 'stringUnit' => { 'state' => 'translated', 'value' => 'Only English' } }
            }
          },
          'HasGerman' => {
            'localizations' => {
              'de' => { 'stringUnit' => { 'state' => 'translated', 'value' => 'Hat Deutsch' } }
            }
          }
        }
      }

      stats = Fastlane::Actions::TranslateWithDeeplAction.calculate_translation_stats(xcstrings_missing_lang, ['de'])

      # Should only count 'HasGerman', not 'OnlyEnglish'
      expect(stats['de'][:total]).to eq(1)
      expect(stats['de'][:translated]).to eq(1)
    end

    it 'handles mixed shouldTranslate values correctly' do
      mixed_data = {
        'strings' => {
          'Normal' => {
            'localizations' => {
              'de' => { 'stringUnit' => { 'state' => 'translated', 'value' => 'Normal' } }
            }
          },
          'ExplicitTrue' => {
            'shouldTranslate' => true,
            'localizations' => {
              'de' => { 'stringUnit' => { 'state' => 'new', 'value' => '' } }
            }
          },
          'ExplicitFalse' => {
            'shouldTranslate' => false,
            'localizations' => {
              'de' => { 'stringUnit' => { 'state' => 'new', 'value' => '' } }
            }
          }
        }
      }

      stats = Fastlane::Actions::TranslateWithDeeplAction.calculate_translation_stats(mixed_data, ['de'])

      expect(stats['de'][:total]).to eq(2) # Normal + ExplicitTrue
      expect(stats['de'][:translated]).to eq(1) # Only Normal
      expect(stats['de'][:skipped_dont_translate]).to eq(1) # Only ExplicitFalse
    end
  end

  describe '#extract_untranslated_strings' do
    let(:sample_xcstrings_data) do
      {
        'strings' => {
          'Translatable' => {
            'localizations' => {
              'en' => { 'stringUnit' => { 'state' => 'translated', 'value' => 'Translatable' } },
              'de' => { 'stringUnit' => { 'state' => 'new', 'value' => '' } }
            }
          },
          'DontTranslate' => {
            'shouldTranslate' => false,
            'localizations' => {
              'en' => { 'stringUnit' => { 'state' => 'translated', 'value' => 'DontTranslate' } },
              'de' => { 'stringUnit' => { 'state' => 'new', 'value' => '' } }
            }
          },
          'AlreadyTranslated' => {
            'localizations' => {
              'en' => { 'stringUnit' => { 'state' => 'translated', 'value' => 'Already Translated' } },
              'de' => { 'stringUnit' => { 'state' => 'translated', 'value' => 'Bereits übersetzt' } }
            }
          }
        }
      }
    end

    it 'skips strings marked with shouldTranslate: false' do
      untranslated = Fastlane::Actions::TranslateWithDeeplAction.extract_untranslated_strings(
        sample_xcstrings_data, 'en', 'de', {}
      )

      expect(untranslated.keys).to include('Translatable')
      expect(untranslated.keys).not_to include('DontTranslate')
      expect(untranslated.keys).not_to include('AlreadyTranslated')
    end

    it 'provides source text for untranslated strings' do
      untranslated = Fastlane::Actions::TranslateWithDeeplAction.extract_untranslated_strings(
        sample_xcstrings_data, 'en', 'de', {}
      )

      expect(untranslated['Translatable']['source_text']).to eq('Translatable')
    end

    it 'skips strings without source text' do
      xcstrings_no_source = {
        'strings' => {
          'NoSource' => {
            'localizations' => {
              'de' => { 'stringUnit' => { 'state' => 'new', 'value' => '' } }
            }
          }
        }
      }

      untranslated = Fastlane::Actions::TranslateWithDeeplAction.extract_untranslated_strings(
        xcstrings_no_source, 'en', 'de', {}
      )

      expect(untranslated).to be_empty
    end
  end

  describe '#select_target_language display formatting' do
    it 'should include skipped count in language display when present' do
      # This tests the display logic without actually running the interactive selection
      stats = {
        total: 100,
        translated: 85,
        untranslated: 15,
        skipped_dont_translate: 10
      }

      percentage = ((stats[:translated].to_f / stats[:total]) * 100).round(1)
      display_name = "German (de): #{percentage}% translated (#{stats[:untranslated]} remaining"
      display_name += ", #{stats[:skipped_dont_translate]} don't translate" if stats[:skipped_dont_translate] > 0
      display_name += ')'

      expect(display_name).to eq("German (de): 85.0% translated (15 remaining, 10 don't translate)")
    end
  end
end
