require 'rubygems'
require 'bundler'
Bundler.require(:production)

# Grizzly handles this GlassFish app.
require 'rack/handler/grizzly'

require 'skat'
require 'caruby/helpers/log'

# Open the logger.
logger = CaRuby::Log.instance.open('/var/log/skat.log')
use Rack::CommonLogger, logger

run Skat::App
