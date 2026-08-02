# frozen_string_literal: true

require_relative "lib/al_email_protect/version"

Gem::Specification.new do |spec|
  spec.name = "al_email_protect"
  spec.version = AlEmailProtect::VERSION
  spec.authors = ["al-folio maintainers"]
  spec.email = ["maintainers@al-folio.dev"]

  spec.summary = "Email obfuscation plugin for al-folio v1.x"
  spec.description = "Hides mailto: addresses from scrapers and copies them to the clipboard on click instead."
  spec.homepage = "https://github.com/al-org-dev/al-email-protect"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7"

  spec.metadata = {
    "allowed_push_host" => "https://rubygems.org",
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
  }

  spec.files = Dir["lib/**/*", "LICENSE", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "jekyll", ">= 3.9", "< 5.0"
  spec.add_dependency "liquid", ">= 4.0", "< 6.0"

  spec.add_development_dependency "bundler", ">= 2.0", "< 3.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
