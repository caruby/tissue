require 'date'
require File.dirname(__FILE__) + '/lib/catissue/version'

Gem::Specification.new do |s|
  s.name          = "caruby-tissue"
  s.summary       = "Ruby facade for the caTissue application" 
  s.description   = s.summary + '. See caruby.rubyforge.org for more information.'
  s.version       = CaTissue::VERSION
  s.date          = Date.today
  s.author        = "OHSU"
  s.email         = "caruby.org@gmail.com"
  s.homepage      = "http://caruby.rubyforge.org/tissue.html"
  s.files         = Dir.glob("{bin,conf,examples,lib}/**/*") + ['History.md', 'LEGAL', 'LICENSE', 'README.md']
  s.require_path  = 'lib'
  s.bindir        = 'bin'
  s.executables   = `git ls-files -- bin/*`.split("\n").map{|f| File.basename(f)}
  s.test_files    = Dir['test/lib/**/*.rb']
  s.add_dependency 'bundler'
  s.add_dependency 'caruby-core', '>= 2.1.1'
  s.add_development_dependency 'yard'
  s.add_development_dependency 'rake'
  s.has_rdoc      = 'yard'
  s.license       = 'MIT'
  s.rubyforge_project = 'caruby'
end
