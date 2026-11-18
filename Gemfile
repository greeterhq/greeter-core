# frozen_string_literal: true

source 'https://rubygems.org'

# No `ruby` version directive here: CI runs the latest Ruby 3.3.x
# (env.RUBY_VERSION "3.3"), so an exact pin fails bundler's version check
# whenever the runner's patch moves. The 3.3 family is pinned by CI and by the
# tracked .ruby-version (local development), and the gemspec requires >= 3.3.0.

gemspec

group :development, :test do
  gem 'rake', require: false
  gem 'rspec', '~> 3.13'
  gem 'rubocop', require: false
  gem 'rubocop-rspec', require: false
  gem 'simplecov', require: false
end
