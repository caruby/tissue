#!/usr/bin/env jruby
#

# load the required gems
require 'rubygems'
begin
  gem 'caruby-tissue'
rescue LoadError
  # if the gem is not available, then try a local source
  $:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
  $:.unshift File.join(File.dirname(__FILE__), '..', 'examples', 'galena', 'lib')
end

# the default log file
DEF_LOG_FILE = 'log/migration.log'

require 'catissue'
require 'catissue/cli/command'

require 'galena/seed/defaults'

CaTissue::Command.new.execute { Galena::Seed.defaults.ensure_exists }