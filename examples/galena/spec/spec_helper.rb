require 'rubygems'
require 'bundler/setup'
Bundler.require(:test, :development)

require 'galena'

# Open the logger.
Jinx::Log.instance.open(File.expand_path(Galena::LOG), :debug => true)

# Include the test utility classes.
Dir.glob(File.dirname(__FILE__) + '/support/**/*.rb').each { |f| require f }
