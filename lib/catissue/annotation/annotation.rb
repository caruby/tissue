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
    
    # @return [Annotatable, nil] the hook object which owns this annotation, or nil if this annotation
    #   is not directly owned by a hook entity
    def hook
      pxy_attr_md = self.class.proxy_attribute_metadata
      send(pxy_attr_md.reader) if pxy_attr_md
    end
    
    # If there is no conventional owner, then try the hook.
    #
    # caTissue alert - DE annotations have a physical dependency ownership model that is at odds
    # with the logical model. An annotation does not directly reference its static hook owner
    # instance. Rather, it references the hook proxy which stands in for the hook entity in the
    # annotation package. 
    #
    # @return the {CaRuby::Resource#owner} or the {#hook}
    def owner
      super or hook
    end
    
    # @return [Proxy, nil] the proxy which references this annotation, or nil if this is not a
    #   primary annotation
    def proxy
      # the annotation owner hook instance 
      ownr = hook || return
      # the hook -> annotation reference attribute
      attr = self.class.hook_proxy_attribute
      if attr.nil? then
        raise AnnotationError.new("Primary annotation #{qp} references hook #{hook} but doesn't have a hook proxy attribute")
      end
      # the owner proxy for the attribute
      ownr.annotation_proxy(attr)
    end
  end
end
