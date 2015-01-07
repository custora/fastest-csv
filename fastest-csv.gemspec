# -*- encoding: utf-8 -*-
require File.expand_path('../lib/fastest-csv/version', __FILE__)

Gem::Specification.new do |gem|

  gem.name          = "fastest-csv"
  gem.authors       = ["Maarten Oelering", "Jon Pospischil", "El-ad David Amir", "Andrew Lim"]
  gem.email         = ["maarten@brightcode.nl", "pospischil@gmail.com", "elad@custora.com", "andy@custora.com"]
  gem.summary       = %q{Fastest standard CSV parser for MRI Ruby}
  gem.description   = gem.summary
  gem.homepage      = "https://github.com/custora/fastest-csv"
  gem.licenses      = ['MIT', 'BSD']

  gem.files         = `git ls-files`.split($\)
  gem.require_paths = ["lib"]
  gem.version       = FastestCSV::VERSION

  gem.extensions  = ['ext/csv_parser/extconf.rb']

  gem.add_development_dependency 'rake-compiler', '~> 0.9'
  gem.add_development_dependency 'minitest', '~> 5.4'
  gem.add_development_dependency 'yard', '~> 0.8.7'

end
