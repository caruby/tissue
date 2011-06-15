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
    
#    # @return [Annotatable, nil] the annotated domain object, or nil if this annotation
#    #   is not {AnnotationClass#primary?}.
#    def hook
#      pxy_attr_md = self.class.proxy_attribute_metadata || return
#      pxy = send(pxy_attr_md.reader) || return
#      
#      
#      puts "ann1 #{self} #{pxy_attr_md} #{pxy.qp} #{pxy.hook.qp}"
#      puts "***\n#{caller.qp}\n****"
#      
#      pxy.hook
#    end  
#    
#    # Assigns this annotation to the given hook object.
#    # This method is a short-cut for setting the annotation proxy, e.g.:
#    #   labs.hook = pnt
#    # is equivalent to:
#    #   labs.clinical = pnt.clinical
#    # @param [Annotatable] obj the annotated domain object
#    # @raise [AnnotationError] if this annotation's class does not have a proxy reference attribute
#    def hook=(obj)
#      attr = self.class.hook_proxy_attribute
#      if attr.nil? then
#        raise AnnotationError.new("Annotation class #{self.class} does not have a proxy reference attribute")
#      end
#      # the owner proxy for the attribute
#      pxy = obj.annotation_proxy(self.class.domain_module)
#      set_attribute(self.class.proxy_attribute, pxy)
#    end
#    
#    # @return [Proxy, nil] the proxy which references this annotation, or nil if this is not a
#    #   primary annotation
#    def proxy
#      # the proxy attribute
#      attr = self.class.proxy_attribute
#      # the proxy value
#      pxy = send(attr) if attr
#      return pxy if pxy
#      # Lazy initialize the hook proxy:
#      # the annotation owner hook instance 
#      h = hook || return
#      # the owner proxy for the attribute
#      h.annotation_proxy(self.class.annotation_module)
#    end
  end
end
