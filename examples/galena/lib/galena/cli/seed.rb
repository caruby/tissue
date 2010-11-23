#!/usr/bin/env jruby
#
# == Synopsis
#
# catissue-seed-galena.rb: seeds the Galena example administrative objects in the database
#
# == Usage
#
# catissue-seed-galena.rb [options] file
#
# --help, -h:
# print this help message and exit
#
# --log file, -l file:
# log file (default ./log/migration.log)
#
# --debug, -d:
# print debug messages to log (optional)
#
# == License
#
# This program is licensed under the terms of the +LEGAL+ file in
# the source distribution.

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