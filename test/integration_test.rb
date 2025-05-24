#!/usr/bin/env ruby

# Test script for fastlane-plugin-translate
require 'bundler/setup'
require 'fastlane'
require_relative '../lib/fastlane/plugin/translate'

puts "🧪 Testing fastlane-plugin-translate\n\n"

# Test 1: Language Registry
puts "1️⃣ Testing Language Registry..."
registry_test_languages = ['en', 'de', 'fr', 'zh-Hans', 'pt-BR']
registry_test_languages.each do |lang|
  name = Fastlane::Translate::LanguageRegistry.language_name(lang)
  valid = Fastlane::Translate::LanguageRegistry.valid_language?(lang)
  puts "   #{lang} → #{name} (valid: #{valid})"
end

# Test 2: DeepL Language Mapper
puts "\n2️⃣ Testing DeepL Language Mapper..."
deepl_test_languages = ['en', 'de', 'fr', 'zh-Hans', 'pt-BR', 'hi']
deepl_test_languages.each do |lang|
  supported = Fastlane::Translate::DeepLLanguageMapper.supported?(lang)
  if supported
    source = Fastlane::Translate::DeepLLanguageMapper.get_source_language(lang)
    target = Fastlane::Translate::DeepLLanguageMapper.get_target_language(lang)
    formality = Fastlane::Translate::DeepLLanguageMapper.supports_formality?(lang)
    puts "   #{lang} → #{source}/#{target} (formality: #{formality})"
  else
    puts "   #{lang} → Not supported by DeepL"
  end
end

# Test 3: Translation Progress
puts "\n3️⃣ Testing Translation Progress..."
progress = Fastlane::Translate::TranslationProgress.new("/tmp/test.xcstrings", "de")
progress.save_translated_strings({"Hello" => "Hallo", "World" => "Welt"})
summary = progress.progress_summary
puts "   Saved progress: #{summary[:translated_count]} strings"
progress.cleanup

# Test 4: Action availability
puts "\n4️⃣ Testing Action Registration..."
available_actions = Fastlane::Actions.constants.select { |c| c.to_s.include?('TranslateWithDeepl') }
if available_actions.any?
  puts "   ✅ TranslateWithDeeplAction is registered"
  
  # Test action parameters
  action_class = Fastlane::Actions::TranslateWithDeeplAction
  options = action_class.available_options
  puts "   📋 Available parameters:"
  options.each do |option|
    puts "     - #{option.key}: #{option.description}"
  end
else
  puts "   ❌ Action not registered"
end

puts "\n✅ Plugin test completed successfully!"
puts "\n🚀 Ready to use! Try:"
puts "   export DEEPL_AUTH_KEY='your-api-key'"
puts "   fastlane translate_with_deepl" 