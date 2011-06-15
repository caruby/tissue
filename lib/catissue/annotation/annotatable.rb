require 'catissue/annotation/annotatable_class'

module CaTissue
  # {CaTissue::Resource} annotation hook mix-in.
  module Annotatable
    def method_missing(mth, *args)
      name = mth.to_s
      # remove trailing assignment '=' character if present
      attr = name =~ /=$/ ? name.chop.to_sym : mth
      # If an annotation can be generated on demand, then resend the method.
      # Otherwise, delegate to super for the standard error.
      begin
        self.class.annotation_attribute?(attr) ? send(mth, *args) : super
      rescue AnnotationError
        raise
      rescue Exception
        super
      end
    end
    
    # Creates a {Annotation::Proxy} whose hook reference is set to this annotatable object.
    #
    # @param [Class] klass the proxy class
    # @return [Resource] the new proxy
    def create_proxy(klass)
      # make the proxy instance
      pxy = klass.new
      # set the proxy hook reference to this hook instance
      pxy.hook = self
      logger.debug { "Generated #{qp} annotation proxy #{pxy} on demand." }
      pxy
    end
    
    # @param [AnnotationModule] mod the annotation module
    # @return [Annotation] the hook -> proxy attribute
    # @raise (see AnnotatableClass#annotation_proxy_attribute)
    def annotation_proxy(mod)
      pxy_attr = self.class.annotation_proxy_attribute(mod)
      # the hook -> proxy attribute value
      send(pxy_attr)
    end
  end
end
