#!/usr/bin/env jruby
#
# == Synopsis
#
# catissue-migrate-galena: migrates the Galena example to caTissue
#
# == Usage
#
# catissue-migrate-galena.rb [options] file
#
# See catissue-migrate.rb for the argments
#
# == License
#
# This program is licensed under the terms of the +LEGAL+ file in
# the source distribution.

# Load the caruby-tissue gem.
require 'rubygems'
begin
  gem 'caruby-tissue'
rescue LoadError
  # if the gem is not available, then try a local source
  $:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
end

# Add the example library to the Ruby class load path. 
$:.unshift File.join(File.dirname(__FILE__), '..', 'examples', 'galena', 'lib')

# the default log file
DEF_LOG_FILE = 'log/migration.log'

# Load the caRuby classes.
require 'catissue'
require 'catissue/migration/command'
require 'galena/seed/defaults'

# Seed the database, if necessary.
Galena.seed

# Migrate the example input using the command line arguments.
CaTissue::CLI::Migrate.new.start