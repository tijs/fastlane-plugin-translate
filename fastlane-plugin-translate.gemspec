lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/translate/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-translate'
  spec.version       = Fastlane::Translate::VERSION
  spec.author        = 'Tijs Teulings'
  spec.email         = 'hello@tijs.org'

  spec.summary       = 'Automatically translate iOS Localizable.xcstrings files using translation APIs'
  spec.description   = 'A fastlane plugin that automatically translates untranslated strings in Localizable.xcstrings files using DeepL API. Features include progress tracking, formality options, context extraction, and comprehensive error handling.'
  spec.homepage      = "https://github.com/tijs/fastlane-plugin-translate"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.require_paths = ['lib']
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir["{lib,fastlane}/**/*"] + %w(README.md LICENSE)
  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})

  # Don't add a dependency to fastlane or fastlane_re
  # since this would cause a circular dependency
  spec.add_dependency 'deepl-rb', '~> 3.0'

  spec.add_development_dependency('bundler')
  spec.add_development_dependency('fastlane', '>= 2.0.0')
  spec.add_development_dependency('pry')
  spec.add_development_dependency('rake')
  spec.add_development_dependency('rspec')
  spec.add_development_dependency('rspec_junit_formatter')
  spec.add_development_dependency('rubocop', '1.12.1')
  spec.add_development_dependency('rubocop-performance')
  spec.add_development_dependency('rubocop-require_tools')
  spec.add_development_dependency('simplecov')

  spec.required_ruby_version = '>= 2.6'
end
