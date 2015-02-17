$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "geonames/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "geonames"
  s.version     = Geonames::VERSION
  s.authors     = ["TODO: Your name"]
  s.email       = ["TODO: Your email"]
  s.homepage    = "TODO"
  s.summary     = "TODO: Summary of Geonames."
  s.description = "TODO: Description of Geonames."

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.files = `git ls-files`.split("\n") - %w[geonames.gemspec Gemfile]
  s.test_files = Dir["test/**/*"]
  s.require_paths = ["lib"]

  s.add_dependency "rails", "~> 4"

end
