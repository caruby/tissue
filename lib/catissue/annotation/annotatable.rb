module CaTissue
  # Annotatable extends {CaTissue::Resource} with annotation capability.
  module Annotatable
    include Resource
    
    # Imports the annotation referenced by the given hook => proxy method on demand,
    # if possible.
    #
    # @param [Symbol] mth the method called
    # @param [Array] args the call arguments
    def method_missing(mth, *args)
      name = mth.to_s
      # remove trailing assignment '=' character if present
      pa = name =~ /=$/ ? name.chop.to_sym : mth
      # If an annotation can be generated on demand, then resend the method.
      # Otherwise, delegate to super for the standard error.
      self.class.ensure_annotations_loaded
      self.class.property_defined?(pa) ? send(mth, *args) : super
    end
    
    # Returns the proxy which mediates access from this hook object to the given annotation.
    # Creates a new proxy on demand if necessary.
    # 
    # @param [Annotation] annotation the annotation to reference by the proxy
    # @return [Proxy] the hook proxy for the given annotation
    def proxy_for(annotation)
      @ann_pxy_hash ||= Jinx::LazyHash.new do |ann|
        prop = self.class.proxy_property_for(annotation.class.annotation_module)
        pxy = prop.type.new
        pxy.hook = self
        if prop.collection? then
          send(pa) << pxy
        else
          send(prop.writer, pxy)
        end
        pxy
      end
      @ann_pxy_hash[annotation]
    end
  end
end
