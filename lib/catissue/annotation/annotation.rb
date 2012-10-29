require 'jinx/metadata/id_alias'
require 'catissue/resource'
require 'catissue/helpers/hash_code'
require 'catissue/annotation/json'

module CaTissue
  # The annotation error class.
  class AnnotationError < StandardError; end
  
  # The caTissue dynamic extension class mix-in.
  #
  # @quirk caTissue Annotation RecordEntry proxy classes implements hashCode with the identifier.
  #   Consequently, a set member is not found after identifier assignment.
  #   The work-around is to include the HashCode mixin, which reimplements the hash and equality
  #   test methods to be invariant with respect to identifier assignment.
  module Annotation
    include JSON, Resource, HashCode
    
    # @return [Resource] this annoation's hook proxy, or nil if this is not a primary annotation 
    def proxy
      pa = self.class.proxy_attribute
      send(pa) if pa
    end
    
    # @return [Resource] this annotation's hook, or nil if this is not a primary annotation 
    def hook
      unless self.class.primary? then
        raise AnnotationError.new("The hook attribute is not defined for the non-primary annotation #{self}")
      end
      pxy = proxy
      pxy.send(pxy.class.hook_property.attribute) if pxy
    end
    
    # Sets this annotation's hook to the given domain object. This method creates a
    # hook-to-annotation intermediary proxy on demand, if necessary. 
    #
    # @param [Resource] the domain object value
    # @raise [AnnotationError] if this is not a primary annotation
    def hook=(obj)
      unless self.class.primary? then
        raise AnnotationError.new("Can't set the non-primary annotation #{self} hook to #{obj}")
      end
      pxy = self.proxy ||= self.class.proxy.new
      pxy.set_property_value(pxy.class.hook_property.attribute, obj)
      logger.debug { "Set the #{annotation_module.qp} #{self} hook to #{obj} via the proxy #{pxy}." }
      obj
    end
  end
end
