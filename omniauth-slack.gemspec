# frozen_string_literal: true

require_relative "lib/omniauth-slack/version"

Gem::Specification.new do |spec|
  spec.name = "omniauth-slack"
  spec.version = Omniauth::Slack::VERSION
  spec.authors = ["TheZero0-ctrl"]
  spec.email = ["ankit@truemark.com.np"]

  spec.summary = "Slack Omniauth strategy with OAuth V2"
  spec.required_ruby_version = ">= 4.0.0"

  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*"]
  spec.require_paths = ["lib"]

  spec.add_dependency "omniauth-oauth2", "~> 1.9"

  spec.add_development_dependency "bundler", "~> 4.0.10"
  spec.add_development_dependency "pry", "~> 0.16.0"
  spec.add_development_dependency "rake", "~> 13.4"
  spec.add_development_dependency "rspec", "~> 3.13.2"
  spec.add_development_dependency "rubocop", "~> 1.86.1"
end
