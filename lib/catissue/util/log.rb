require 'caruby/util/log'
require 'catissue/wustl/logger'

# CaTissue wraps the caTissue Java API.
# See the caRuby[http://http://caruby.rubyforge.org/] home page for more information.
module CaTissue
  private
  
  # Set up the caTissue client logger before loading the class definitions.
  Wustl::Logger.configure
end

