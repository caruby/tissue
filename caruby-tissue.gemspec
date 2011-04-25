require 'date'
require 'catissue/version'

SPEC = Gem::Specification.new do |s|
  s.name          = "caruby-tissue"
  s.summary       = "Ruby facade for caTissue." 
  s.description   = <<-eof
    The caruby-tissue gem applies the caRuby facade to the caTissue application.
  eof
  s.version       = CaTissue::VERSION
  s.date          = Date.today
  s.author        = "OHSU"
  s.email         = "caruby.org@gmail.com"
  s.homepage      = "http://rubyforge.org/projects/caruby/tissue"
  s.platform      = Gem::Platform::RUBY
  s.files         = Dir.glob("{bin,conf,examples,lib,test/{bin,fixtures,lib}}/**/*") + ['History.txt', 'LEGAL', 'LICENSE', 'README.md']
  s.require_paths = ['lib']
  s.bindir = 'bin'
  s.executables = ['crtdump', 'crtexample', 'crtextract', 'crtmigrate', 'crtsmoke']
  s.add_dependency('caruby-core', '>= 1.4.8')
  s.has_rdoc      = 'yard'
  s.license       = 'MIT'
  s.rubyforge_project = 'caruby'
end