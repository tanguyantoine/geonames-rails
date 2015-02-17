$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "geonames/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "geonames"
  s.version     = Geonames::VERSION
  s.authors     = ["TANGUY Antoine"]
  s.email       = ["antoine@tanguy.fr"]
  s.homepage    = "http://www.google.fr"
  s.summary     = "Use geonames datas"
  s.description = "Description of Geonames."

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.files = `git ls-files`.split("\n") - %w[Gemfile]
  s.test_files = Dir["test/**/*"]
  s.require_paths = ["lib"]

  s.add_dependency "rails", "~> 4"
  s.add_runtime_dependency 'ruby-progressbar'
  s.add_runtime_dependency 'rubyzip'

end
