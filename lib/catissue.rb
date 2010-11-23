# This file is the entry point included by applications which reference a CaTissue object or service.

# the caRuby core gem
require 'rubygems'
begin
  gem 'caruby-core'
rescue LoadError
  # if the gem is not available, then try a local development source
  $:.unshift File.join(File.dirname(__FILE__), '..', '..', 'caruby', 'lib')
end

require 'caruby/util/log'
require 'catissue/util/log'
require 'catissue/resource'
require 'catissue/database'

# CaTissue wraps the caTissue Java API.
# See the caRuby[http://http://caruby.rubyforge.org/] home page for more information.
module CaTissue
  # @param [<String>] nodes the path components relative to the caRuby Tissue source directory
  # @return [String] the file path to the specified path components
  def self.path(*nodes)
    root = File.join(File.dirname(__FILE__), '..')
    File.expand_path(File.join(*nodes), root)
  end
end
