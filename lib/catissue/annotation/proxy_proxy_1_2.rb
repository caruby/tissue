module CaTissue
  module Annotation
    # A caTissue 1.2 annotation module has two RecordEntry classes, as described in
    # the {IntegrationMetadata#integrate} quirk rubydoc. A ProxyProxy_1_2 is the
    # second level of indirection in the convoluted 1.2 mechanism that leads from
    # a static hook -> integration proxy -> proxy proxy -> annotation.
    module ProxyProxy_1_2
      #  Creates the inverse proxy proxy -> integration proxy reference.
      #
      # @param [Class] klass the integration proxy class
      # @return [Symbol] the proxy proxy -> integration proxy attribute
      def create_integration_proxy_property(klass)
        attr_accessor(:integration_proxy)
        ip = add_attribute(:integration_proxy, klass)
        logger.debug { "Created the pre-2.0 caTissue annotation proxy proxy #{self} property #{ip} reference to #{klass}." }
        ip
      end
    end
  end
end
