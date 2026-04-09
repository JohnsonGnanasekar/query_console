require_relative "lib/query_console/version"

Gem::Specification.new do |spec|
  spec.name        = "query_console"
  spec.version     = QueryConsole::VERSION
  spec.authors     = ["Johnson Gnanasekar"]
  spec.email       = ["johnson@example.com"]
  spec.homepage    = "https://github.com/JohnsonGnanasekar/query_console"
  spec.summary     = "Secure, mountable Rails SQL console with read-only enforcement and optional DML support"
  spec.description = "A Rails engine providing a web-based SQL query console with security-first design: read-only by default, optional DML (INSERT/UPDATE/DELETE) with confirmation dialogs, flexible authorization, comprehensive audit logging, and query execution plans."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/JohnsonGnanasekar/query_console/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/JohnsonGnanasekar/query_console/issues"
  spec.metadata["documentation_uri"] = "https://github.com/JohnsonGnanasekar/query_console/blob/main/README.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.required_ruby_version = ">= 3.1.0"

  spec.add_dependency "rails", ">= 7.0.0"
  spec.add_dependency "turbo-rails", "~> 2.0"
  spec.add_dependency "stimulus-rails", "~> 1.3"

  spec.add_development_dependency "rspec-rails", "~> 7.0"
  spec.add_development_dependency "sqlite3", "~> 2.0"
end
