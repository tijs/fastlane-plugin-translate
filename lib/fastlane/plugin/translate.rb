# frozen_string_literal: true

require 'fastlane/plugin/translate/version'

module Fastlane
  module Translate
    # Return all .rb files inside the "actions" and "helper" directory
    def self.all_classes
      Dir[File.expand_path('**/{actions,helper}/*.rb', File.dirname(__FILE__))]
    end
  end
end

# By default we want to import all available actions and helpers
# A plugin can contain any number of actions and plugins
Fastlane::Translate.all_classes.each do |current|
  require current
end

# Require our language support modules
require_relative 'translate/language_registry'
require_relative 'translate/deepl_language_mapper'
require_relative 'translate/translation_progress'
