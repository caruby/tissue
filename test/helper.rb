require 'rubygems'
require 'bundler/setup'
Bundler.require(:test, :development)

# Open the logger.
unless Jinx::Log.instance.open? then
  Jinx::Log.instance.open(File.dirname(__FILE__) + '/results/log/catissue.log',
    :shift_age => 5, :shift_size => 1048576, :debug => true)
end

# Load the default test object definitions.
require File.dirname(__FILE__) + '/helpers/seed'
