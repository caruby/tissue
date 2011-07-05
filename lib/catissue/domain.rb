require 'caruby/domain'
require 'catissue/resource'
require 'catissue/annotation/annotatable_class'
require 'catissue/wustl/logger'

module CaTissue
  
  private
  
  # The required Java package name.
  PKG = 'edu.wustl.catissuecore.domain'
  
  # The domain class definitions.
  SRC_DIR = File.join(File.dirname(__FILE__), 'domain')

  # Enable the resource metadata aspect.
  md_proc = Proc.new { |klass| AnnotatableClass.extend_class(klass) }
  CaRuby::Domain.extend_module(self, :mixin => Resource, :metadata => md_proc, :package => PKG)
  
  # Set up the caTissue client logger before loading the class definitions.
  Wustl::Logger.configure
  
  # Load the class definitions.
  load_dir(SRC_DIR)
end

