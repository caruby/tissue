require 'catissue/resource'

module CaTissue
  # Annotatable extends {CaTissue::Resource} with annotation capability.
  module Annotatable
    include Resource
    
    def method_missing(mth, *args)
      name = mth.to_s
      # remove trailing assignment '=' character if present
      pa = name =~ /=$/ ? name.chop.to_sym : mth
      # If an annotation can be generated on demand, then resend the method.
      # Otherwise, delegate to super for the standard error.
      begin
        self.class.annotation_attribute?(pa) ? send(mth, *args) : super
      rescue AnnotationError => e
        raise e
      rescue NoMethodError
        super
      end
    end
    
    # @param [Symbol] attribute the hook => proxy attribute
    # @param [Annotation] the annotation
    # @return [Proxy] the hook proxy for the given annotation
    def proxy_for(attribute, annotation)
      @ann_pxy_hash ||= Jinx::LazyHash.new do |ann|
        pxy = self.class.property(attribute).type.new
        pxy.hook = self
        send(attribute) << pxy
        pxy
      end
      @ann_pxy_hash[annotation]
    end
  end
end
