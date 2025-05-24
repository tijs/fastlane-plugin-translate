# frozen_string_literal: true

describe Fastlane::Actions::TranslateWithDeeplAction do
  describe '#run' do
    it 'has proper description' do
      expect(Fastlane::Actions::TranslateWithDeeplAction.description).to include('translate')
      expect(Fastlane::Actions::TranslateWithDeeplAction.description).to include('DeepL')
    end

    it 'supports iOS platform' do
      expect(Fastlane::Actions::TranslateWithDeeplAction.supported?(:ios)).to be true
    end

    it 'does not support Android platform' do
      expect(Fastlane::Actions::TranslateWithDeeplAction.supported?(:android)).to be false
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
end
