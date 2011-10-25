require 'rubygems'
gem 'caruby-core'

require 'caruby/domain'
require 'catissue/annotation/annotatable_class'

# CaTissue wraps the caTissue Java API.
module CaTissue
  # @param [<String>] nodes the path components relative to the caRuby Tissue source directory
  # @return [String] the file path to the specified path components
  def self.path(*nodes)
    root = File.dirname(__FILE__) + '/..'
    File.expand_path(File.join(*nodes), root)
  end
  
  # @param [Module] mod the resource mix-in module to extend with metadata capability
  def self.extend_module(mod)
    # Enable the resource metadata aspect.
    md_proc = Proc.new { |klass| AnnotatableClass.extend_class(klass) }
    CaRuby::Domain.extend_module(self, :mixin => mod, :metadata => md_proc, :package => PKG, :directory => SRC_DIR)
  end
  
  private
  
  # The required Java package name.
  PKG = 'edu.wustl.catissuecore.domain'
  
  # The domain class definitions.
  SRC_DIR = File.dirname(__FILE__) + '/domain'
end

