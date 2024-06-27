# frozen_string_literal: true

require_relative "lib/omniauth-slack/version"

Gem::Specification.new do |spec|
  spec.name = "omniauth-slack"
  spec.version = Omniauth::Slack::VERSION
  spec.authors = ["TheZero0-ctrl"]
  spec.email = ["ankit@truemark.com.np"]

  spec.summary = "Slack Omniauth strategy with OAuth V2"
  spec.required_ruby_version = ">= 2.6.0"

  spec.files = Dir["lib/**/*"]
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "omniauth-oauth2", "~> 1.8"

  spec.add_development_dependency "bundler", "~> 2.5"
  spec.add_development_dependency "pry", "~> 0.14.2"
  spec.add_development_dependency "rake", "~> 13.1"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.60"
end
