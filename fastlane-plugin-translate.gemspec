# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/translate/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-translate'
  spec.version       = Fastlane::Translate::VERSION
  spec.author        = 'Tijs Teulings'
  spec.email         = 'hello@tijs.org'

  spec.summary       = 'Automatically translate iOS Localizable.xcstrings files using DeepL API'
  spec.description   = 'A fastlane plugin to automatically translate iOS Localizable.xcstrings files using DeepL API. Supports progress tracking, formality options, error recovery, and more.'
  spec.homepage      = 'https://github.com/tijs/fastlane-plugin-translate'
  spec.license       = 'MIT'

  spec.files         = Dir['lib/**/*'] + %w[README.md LICENSE]
  spec.require_paths = ['lib']
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.required_ruby_version = '>= 3.3'

  # The name of the C extension
  spec.add_dependency('deepl-rb', '>= 2.5.0')

  spec.add_development_dependency('bundler')
  spec.add_development_dependency('fastlane', '>= 2.0.0')
  spec.add_development_dependency('pry')
  spec.add_development_dependency('rake')
  spec.add_development_dependency('rspec')
  spec.add_development_dependency('rspec_junit_formatter')
  spec.add_development_dependency('rubocop', '1.50.2')
  spec.add_development_dependency('rubocop-performance')
  spec.add_development_dependency('rubocop-require_tools')
  spec.add_development_dependency('simplecov')
end
