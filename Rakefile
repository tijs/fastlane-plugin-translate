# frozen_string_literal: true

require 'bundler/gem_tasks'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

require 'rubocop/rake_task'
RuboCop::RakeTask.new(:rubocop)

RuboCop::RakeTask.new(:rubocop_autocorrect) do |task|
  task.options = ['-A'] # Use '-A' for auto-correct (aggressive), or '-a' for safe auto-correct
end

task(default: %i[spec rubocop])
