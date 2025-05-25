# frozen_string_literal: true

require 'spec_helper'

describe Fastlane::Helper::DeeplLanguageMapperHelper do
  describe '.supported?' do
    it 'returns true for languages supported by DeepL' do
      expect(described_class.supported?('en')).to be true
      expect(described_class.supported?('de')).to be true
      expect(described_class.supported?('fr')).to be true
    end

    it 'returns false for languages not supported by DeepL' do
      expect(described_class.supported?('hi')).to be false
      expect(described_class.supported?('unknown')).to be false
    end
  end

  describe '.get_source_language' do
    it 'returns correct DeepL source language codes' do
      expect(described_class.get_source_language('en')).to eq('EN')
      expect(described_class.get_source_language('de')).to eq('DE')
    end

    it 'returns nil for unsupported languages' do
      expect(described_class.get_source_language('hi')).to be_nil
      expect(described_class.get_source_language('unknown')).to be_nil
    end
  end

  describe '.get_target_language' do
    it 'returns correct DeepL target language codes' do
      expect(described_class.get_target_language('en')).to eq('EN')
      expect(described_class.get_target_language('de')).to eq('DE')
      expect(described_class.get_target_language('en-US')).to eq('EN-US')
    end

    it 'returns nil for unsupported languages' do
      expect(described_class.get_target_language('hi')).to be_nil
      expect(described_class.get_target_language('unknown')).to be_nil
    end
  end

  describe '.supports_formality?' do
    it 'returns true for languages that support formality' do
      expect(described_class.supports_formality?('de')).to be true
      expect(described_class.supports_formality?('fr')).to be true
    end

    it 'returns false for languages that do not support formality' do
      expect(described_class.supports_formality?('en')).to be false
    end

    it 'returns false for unsupported languages' do
      expect(described_class.supports_formality?('hi')).to be false
    end
  end

  describe '.supported_languages_from_list' do
    it 'filters out unsupported languages' do
      input_languages = %w[en de fr hi unknown]
      result = described_class.supported_languages_from_list(input_languages)

      expect(result).to include('en', 'de', 'fr')
      expect(result).not_to include('hi', 'unknown')
    end
  end

  describe '.unsupported_languages' do
    it 'returns only unsupported languages' do
      input_languages = %w[en de fr hi unknown]
      result = described_class.unsupported_languages(input_languages)

      expect(result).to include('hi', 'unknown')
      expect(result).not_to include('en', 'de', 'fr')
    end
  end
end
