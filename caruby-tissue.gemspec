require 'date'
require 'catissue/version'

CaTissue::SPEC = Gem::Specification.new do |s|
  s.name          = "caruby-tissue"
  s.summary       = "Ruby facade for the caTissue application" 
  s.description   = s.summary
  s.version       = CaTissue::VERSION
  s.date          = Date.today
  s.author        = "OHSU"
  s.email         = "caruby.org@gmail.com"
  s.homepage      = "http://caruby.rubyforge.org/tissue.html"
  s.files         = Dir.glob("{bin,conf,examples,lib,test/{bin,fixtures,lib}}/**/*") + ['History.md', 'LEGAL', 'LICENSE', 'README.md']
  s.require_paths = ['lib']
  s.bindir = 'bin'
  s.executables = `git ls-files -- bin/*`.split("\n").map{|f| File.basename(f)}
  s.add_dependency 'caruby-core', '>= 1.5.5'
  if s.respond_to?(:add_development_dependency) then
    %w(bundler yard rake).each { |lib| s.add_development_dependency lib }
  end
  s.has_rdoc      = 'yard'
  s.license       = 'MIT'
  s.rubyforge_project = 'caruby'
end
