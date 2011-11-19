require 'rubygems'
require 'bundler'
Bundler.require(:test, :development)

# Open the logger.
require 'catissue/helpers/log'
CaRuby::Log.instance.open(File.dirname(__FILE__) + '/../results/log/catissue.log',
  :shift_age => 5, :shift_size => 1048576, :debug => true)

# Load the default test object definitions.
require File.dirname(__FILE__) + '/helpers/seed'
