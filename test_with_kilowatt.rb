#!/usr/bin/env ruby

# Test script for fastlane-plugin-translate with Kilowatt project
require 'bundler/setup'
require 'json'
require_relative 'lib/fastlane/plugin/translate'

puts "🧪 Testing with Kilowatt Localizable.xcstrings\n\n"

# Test with actual Kilowatt xcstrings file
kilowatt_path = '../Kilowatt/Kilowatt/Localizable.xcstrings'

unless File.exist?(kilowatt_path)
  puts "❌ Kilowatt Localizable.xcstrings not found at: #{kilowatt_path}"
  exit 1
end

puts "📁 Found Kilowatt xcstrings file: #{kilowatt_path}"

# Parse the file
begin
  xcstrings_data = JSON.parse(File.read(kilowatt_path))
  puts "✅ Successfully parsed xcstrings file"
rescue JSON::ParserError => e
  puts "❌ Failed to parse xcstrings file: #{e.message}"
  exit 1
end

# Extract basic info
source_language = xcstrings_data['sourceLanguage']
total_strings = xcstrings_data['strings'].count

puts "📊 Source language: #{source_language}"
puts "📊 Total strings: #{total_strings}"

# Extract available languages
languages = Set.new
xcstrings_data['strings'].each do |_, string_data|
  next unless string_data['localizations']
  string_data['localizations'].keys.each { |lang| languages.add(lang) }
end

target_languages = (languages - [source_language]).to_a.sort
puts "🌍 Available target languages: #{target_languages.join(', ')}"

# Check DeepL support for each language
puts "\n🔍 DeepL Support Analysis:"
target_languages.each do |lang|
  name = Fastlane::Translate::LanguageRegistry.language_name(lang)
  supported = Fastlane::Translate::DeepLLanguageMapper.supported?(lang)
  
  if supported
    source_deepl = Fastlane::Translate::DeepLLanguageMapper.get_source_language(lang)
    target_deepl = Fastlane::Translate::DeepLLanguageMapper.get_target_language(lang)
    formality = Fastlane::Translate::DeepLLanguageMapper.supports_formality?(lang)
    status = "✅ #{source_deepl} → #{target_deepl}"
    status += " (formality)" if formality
  else
    status = "❌ Not supported"
  end
  
  puts "   #{lang} (#{name}): #{status}"
end

# Calculate translation stats for supported languages
puts "\n📈 Translation Progress for DeepL-supported languages:"
supported_languages = target_languages.select { |lang| Fastlane::Translate::DeepLLanguageMapper.supported?(lang) }

supported_languages.each do |lang_code|
  total = 0
  translated = 0
  
  xcstrings_data['strings'].each do |string_key, string_data|
    next if string_key.empty?
    next unless string_data.dig('localizations', lang_code)
    
    total += 1
    localization = string_data.dig('localizations', lang_code, 'stringUnit')
    
    if localization && localization['state'] == 'translated' && 
       localization['value'] && !localization['value'].empty?
      translated += 1
    end
  end
  
  untranslated = total - translated
  percentage = total > 0 ? ((translated.to_f / total) * 100).round(1) : 0
  
  name = Fastlane::Translate::LanguageRegistry.language_name(lang_code)
  puts "   #{name} (#{lang_code}): #{percentage}% (#{translated}/#{total} translated, #{untranslated} remaining)"
end

# Test context extraction
puts "\n📝 Context Analysis (first 5 strings with comments):"
comment_count = 0
xcstrings_data['strings'].each do |string_key, string_data|
  break if comment_count >= 5
  
  if string_data['comment'] && !string_data['comment'].empty?
    puts "   '#{string_key}' → '#{string_data['comment']}'"
    comment_count += 1
  end
end

puts "   Total strings with comments: #{xcstrings_data['strings'].count { |_, data| data['comment'] && !data['comment'].empty? }}"

puts "\n✅ Analysis completed successfully!"
puts "\n🚀 The plugin is ready to translate your Kilowatt app!"
puts "   Example: fastlane translate_with_deepl target_language:\"de\"" 