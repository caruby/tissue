require 'date'
require File.expand_path('version', File.dirname(__FILE__) + '/lib/catissue')

Gem::Specification.new do |s|
  s.name          = "caruby-tissue"
  s.summary       = "Ruby facade for the caTissue application" 
  s.description   = s.summary
  s.version       = CaTissue::VERSION
  s.date          = Date.today
  s.author        = "OHSU"
  s.email         = "caruby.org@gmail.com"
  s.homepage      = "http://caruby.rubyforge.org/tissue.html"
  s.files         = Dir.glob("{bin,conf,examples,lib,test/{bin,fixtures,lib}}/**/*") + ['History.md', 'LEGAL', 'LICENSE', 'README.md']
  s.require_path  = 'lib'
  s.bindir        = 'bin'
  s.executables   = `git ls-files -- bin/*`.split("\n").map{|f| File.basename(f)}
  s.test_files    = Dir['test/lib/**/*test.rb']
  s.add_dependency 'caruby-core', '>= 1.5.5'
  s.add_development_dependency 'bundler'
  s.add_development_dependency 'yard'
  s.add_development_dependency 'rake'
  s.has_rdoc      = 'yard'
  s.license       = 'MIT'
  s.rubyforge_project = 'caruby'
end
