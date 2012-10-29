module CaTissue
  module Annotation
    # A caTissue 1.2 annotation module has two RecordEntry classes, as described in
    # the {IntegrationMetadata#integrate} quirk rubydoc. Metadata_1_2 adds a
    # composite reference that refers back to the integration proxy.
    module Metadata_1_2
      # Creates the inverse primary annotation -> integration proxy reference
      # attribute by composing the annotation -> proxy proxy -> integration proxy
      # reference path.
      #
      # @param [Property] ann_pp_prop the annotation -> proxy proxy reference property
      # @param [Property] pp_ip_prop the proxy proxy -> integration reference property
      # @return [Property] the annotation -> integration proxy attribute
      def create_integration_proxy_property(ann_pp_prop, pp_ip_prop)
        ip = compose_property(ann_pp_prop, pp_ip_prop)
        logger.debug { "Created the pre-2.0 caTissue annotation #{self} property #{ip} reference to #{ip.type} as the composition of #{ann_pp_prop.type}.#{ann_pp_prop} and #{pp_ip_prop.type}.#{pp_ip_prop}." }
        ip
      end
    end
  end
end
