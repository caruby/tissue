require 'date'

Gem::Specification.new do |s|
  s.name          = "galena"
  s.summary       = "caRuby Tissue example application" 
  s.description   = s.summary
  s.version       = CaTissue::VERSION
  s.date          = Date.today
  s.author        = "OHSU"
  s.email         = "caruby.org@gmail.com"
  s.homepage      = "http://caruby.rubyforge.org/tissue.html"
  s.files         =  File.dirname(__FILE__)
  s.require_path  = 'lib'
  s.add_dependency 'caruby-tissue'
  s.has_rdoc      = 'yard'
  s.license       = 'MIT'
  s.rubyforge_project = 'caruby'
end
