# frozen_string_literal: true

require 'spec_helper'

describe Fastlane::Translate::LanguageRegistry do
  describe '.language_name' do
    it 'returns correct language names for common languages' do
      expect(described_class.language_name('en')).to eq('English')
      expect(described_class.language_name('de')).to eq('German')
      expect(described_class.language_name('fr')).to eq('French')
      expect(described_class.language_name('zh-Hans')).to eq('Chinese (Simplified)')
      expect(described_class.language_name('pt-BR')).to eq('Portuguese (Brazil)')
    end

    it 'returns the language code itself for unknown languages' do
      expect(described_class.language_name('unknown')).to eq('unknown')
    end
  end

  describe '.valid_language?' do
    it 'returns true for known languages' do
      expect(described_class.valid_language?('en')).to be true
      expect(described_class.valid_language?('de')).to be true
      expect(described_class.valid_language?('fr')).to be true
    end

    it 'returns false for unknown languages' do
      expect(described_class.valid_language?('unknown')).to be false
    end
  end
end
