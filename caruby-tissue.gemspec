require 'date'
require File.dirname(__FILE__) + '/lib/catissue/version'

Gem::Specification.new do |s|
  s.name          = 'caruby-tissue'
  s.summary       = 'Ruby facade for the caTissue application' 
  s.description   = s.summary + '. See caruby.rubyforge.org for more information.'
  s.version       = CaTissue::VERSION
  s.date          = Date.today
  s.author        = 'OHSU'
  s.email         = 'caruby.org@gmail.com'
  s.homepage      = 'http://caruby.rubyforge.org/tissue.html'
  s.files         = Dir['{bin,conf,examples,lib}/**/*'] +
    Dir['examples/*/{Gemfile,Rakefile,README.md}'] +
    Dir['examples/*/{bin,conf,data,lib,spec}/**/*'] +
    ['History.md', 'LEGAL', 'LICENSE', 'README.md', 'Gemfile']
  s.require_path  = 'lib'
  s.bindir        = 'bin'
  s.executables   = Dir['bin/*'].map{ |f| File.basename(f) }
  s.test_files    = Dir.glob('test/lib/**/*.rb')
  s.add_runtime_dependency 'bundler'
  s.add_runtime_dependency 'jinx', '>= 2.1.1'
  s.add_runtime_dependency 'jinx-json', '>= 2.1.1'
  s.add_runtime_dependency 'uom', '>= 1.2.2'
  s.add_development_dependency 'yard'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec', '>= 2.6'
  s.requirements   << 'the caTissue API client'
  s.has_rdoc      = 'yard'
  s.license       = 'MIT'
  s.rubyforge_project = 'caruby'
end
