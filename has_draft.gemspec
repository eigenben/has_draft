require_relative "lib/has_draft/version"

Gem::Specification.new do |s|
  s.name        = "has_draft"
  s.version     = HasDraft::VERSION
  s.author      = "Ben Hughes"
  s.email       = "ben@railsgarden.com"
  s.homepage    = "https://github.com/eigenben/has_draft"
  s.summary     = "Attach drafts to your ActiveRecord models."
  s.description = "Allows for your ActiveRecord models to have drafts which are stored in a separate duplicate table."
  s.license     = "MIT"

  s.metadata = {
    "source_code_uri" => s.homepage,
    "changelog_uri" => "#{s.homepage}/blob/master/CHANGELOG.md",
    "bug_tracker_uri" => "#{s.homepage}/issues"
  }

  s.files = Dir["lib/**/*", "LICENSE", "README.md", "CHANGELOG.md"]
  s.require_path = "lib"

  s.required_ruby_version = ">= 3.0"

  s.add_dependency "activerecord", ">= 6.1"
end
