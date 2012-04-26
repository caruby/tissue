require 'fileutils'
require File.expand_path('version', File.dirname(__FILE__) + '/lib/catissue')

# the gem name
GEM = 'caruby-tissue'
GEM_VERSION = CaTissue::VERSION

WINDOWS = (Config::CONFIG['host_os'] =~ /mingw|win32|cygwin/ ? true : false) rescue false
SUDO = WINDOWS ? '' : 'sudo'

desc 'Builds the gem'
task :gem do
  sh "jgem build #{GEM}.gemspec"
end

desc 'Installs the gem'
task :install => :gem do
  sh "#{SUDO} jgem install #{GEM}-#{GEM_VERSION}.gem"
end

desc 'Documents the API'
task :doc do
  FileUtils.rm_rf 'doc/api'
  sh "yardoc"
  #  Make the example documentation separately.
  FileUtils.rm_rf 'examples/galena/doc/api'
  sh "yardoc -o examples/galena/yardoc/doc/api examples/galena"
end

desc 'Runs the example specs'
task :spec do
  Dir[File.dirname(__FILE__) + '/examples/galena/spec/**/*_spec.rb'].each { |f| sh "cd examples/galena; rspec #{f}" rescue nil }
end

desc 'Runs the unit tests'
task :unit do
  Dir['test/**/*_test.rb'].each { |f| sh "jruby #{f}" rescue nil }
end

desc 'Runs all tests'
task :test => [:spec, :unit]
