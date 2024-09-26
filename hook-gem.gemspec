# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "hook"
  spec.version = "1.0.0"
  spec.authors = ["Genar Trias Ortiz"]
  spec.email = ["gtrias@gmail.com"]

  spec.summary = "A gem to create decorator hooks approach for any ruby class, it supports before, after and around hooks"
  spec.description = "A gem to create decorator hooks approach for any ruby class"
  spec.homepage = "https://github.com/gtrias/hook"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/gtrias/hook"
  spec.metadata["changelog_uri"] = "https://github.com/gtrias/hook"

  # Specify which files should be added to the gem when it is released.
  spec.files = ["lib/hook/hook.rb"]
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
