require 'date'
require File.expand_path('version', File.dirname(__FILE__) + '/lib/catissue/web_service')

Gem::Specification.new do |s|
  s.name          = "caruby-tissue-web-service"
  s.summary       = "Light-weight caTissue web service."
  s.description   = s.summary
  s.version       = CaTissue::WebService::VERSION
  s.date          = Date.today
  s.author        = "OHSU"
  s.email         = "caruby.org@gmail.com"
  s.homepage      = "http://caruby.rubyforge.org/tissuews.html"
  s.platform      = Gem::Platform::RUBY
  s.files         = Dir.glob("{bin,conf,examples,lib,test/{bin,fixtures,lib}}/**/*") + ['History.md', 'LEGAL', 'LICENSE', 'README.md']
  s.require_path = 'lib'
  s.bindir = 'bin'
  s.executables = ['crtws']
  s.add_dependency 'caruby-tissue', '>= 1.5.5'
  s.add_development_dependency 'bundler'
  s.add_development_dependency 'yard'
  s.add_development_dependency 'rake'
  s.has_rdoc      = 'yard'
  s.license       = 'MIT'
  s.rubyforge_project = 'caruby'
end
