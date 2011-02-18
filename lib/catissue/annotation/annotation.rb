require 'caruby/resource'
require 'caruby/domain/id_alias'

module CaTissue
  # Annotation acceess error class.
  class AnnotationError < StandardError; end
  
  # Annotation class mix-in.
  module Annotation
    include CaRuby::Resource, CaRuby::IdAlias

    # Returns the CaTissue::Database which stores this object.
    def database
      CaTissue::Database.instance
    end
    
    # Updates the annotation proxy to reflect the hook, if necessary.
    #
    # @see Proxy#ensure_identifier_reflects_hook
    def ensure_proxy_reflects_hook
      pxy = proxy || return
      pxy.ensure_identifier_reflects_hook
    end
    
    # @return [Annotatable] the hook object which owns this annotation, or nil if this annotation
    #   is not directly owned by a hook entity
    def hook
      pxy_attr = self.class.proxy_attribute
      send(pxy_attr) if pxy_attr
    end
    
    # If there is no conventional owner, then try the hook.
    #
    # @return the {CaRuby::Resource#owner} or the {#hook}
    def owner
      super or hook
    end
    
    # @return [Proxy] the proxy which references this annotation
    def proxy
      # the annotation owner hook instance 
      ownr = hook || return
      # the hook -> annotation reference attribute
      attr = self.class.hook_proxy_attribute
      # the owner proxy for the attribute
      ownr.annotation_proxy(attr)
    end
  end
end
