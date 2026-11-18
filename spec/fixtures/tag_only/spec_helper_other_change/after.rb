# frozen_string_literal: true

require 'greeter/core'
require 'greeter/core/testing'

# Spec-side helpers (slug rule, trace-check, repo-trace formatter). Spec files
# under spec/support are loaded by rspec itself, not here.
Dir[File.join(__dir__, 'support', '**', '*.rb')].each do |path|
  require path unless path.end_with?('_spec.rb')
end

RSpec.configure do |config|
  config.order = :defined
end
