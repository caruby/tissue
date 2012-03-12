require 'date'
require File.expand_path('version', File.dirname(__FILE__) + '/lib/galena')

Gem::Specification.new do |s|
  s.name          = 'galena'
  s.summary       = 'caRuby Tissue example application' 
  s.description   = s.summary + '. See the README for more information.'
  s.version       = Galena::VERSION
  s.date          = Date.today
  s.author        = 'OHSU'
  s.email         = 'caruby.org@gmail.com'
  s.platform      = 'java'
  s.homepage      = 'http://caruby.rubyforge.org/tissue.html'
  s.files         = Dir.glob('{bin,conf,lib}/**/*') + ['README.md', 'Gemfile']
  s.test_files    = Dir.glob('spec/**/*.rb')
  s.require_path  = 'lib'
  s.bindir        = 'bin'
  s.executables   = Dir['bin/*'].map { |f| File.basename(f) }
  s.add_runtime_dependency 'caruby-tissue', '>= 2.1.1'
  s.add_development_dependency 'bundler'
  s.add_development_dependency 'rspec', '>= 2.6'
  s.has_rdoc      = 'yard'
  s.license       = 'MIT'
end
