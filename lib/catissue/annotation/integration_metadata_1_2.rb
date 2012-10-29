require 'catissue/annotation/integration_metadata'
require 'catissue/annotation/proxy_proxy_1_2'
require 'catissue/annotation/metadata_1_2'

module CaTissue
  module Annotation
    # This IntegrationMetadata mix-in augments {IntegrationMetadata} with methods
    # that tie together the integration proxy and its proxy proxy.
    module IntegrationMetadata_1_2
      include IntegrationMetadata
      
      # @return [Property] the reference to the proxy proxy
      attr_reader :proxy_proxy_property
      
      private
      
      # Composes the 1.2 proxy -> proxy -> annotation references as described in the
      # {#integrate} quirk rubydoc.
      #
      # @param [Module] mod (see #integrate)
      def integrate_proxy_proxy(mod)
        begin
          # the proxy proxy class
          klass = mod.const_get(name.demodulize)
        rescue NameError
          logger.error("The pre-2.0 caTissue annotation proxy #{self} does not have a counterpart in #{mod}.")
          raise
        end
        logger.debug { "The pre-2.0 caTissue annotation proxy #{self} #{mod} counterpart is #{klass}." }
        # Make the inverse proxy proxy -> integration proxy reference.
        klass.extend(ProxyProxy_1_2)
        pp_ip_prop = klass.create_integration_proxy_property(self)
        # Make the integration proxy -> proxy proxy dependent reference.
        attr_create_on_demand_accessor(:proxy_proxy) { klass.new }
        @proxy_proxy_property = add_attribute(:proxy_proxy, klass)
        add_dependent_property(@proxy_proxy_property)
        logger.debug { "Added the pre-2.0 caTissue annotation proxy #{self} dependent property #{@proxy_proxy_property} reference to #{klass}." }
        klass.properties.each do |prop|
          next unless mod.contains?(prop.type)
          # Infer the inverses now, since an inverse is a prerequisite for property
          # composition. Inverses are otherwise only detected for dependencies.
          # However, the annotation dependency hierarchy is built below, so we
          # preempt the dependency inverse detection here.
          ann_pp_attr = klass.infer_property_inverse(prop)
          unless ann_pp_attr then
            raise AnnotationError.new("The annotation #{mod.qp} proxy proxy #{proxy_proxy} #{prop} reference to #{prop.type} was not detected.")
          end
          compose_property(@proxy_proxy_property, prop)
          prop.type.extend(Metadata_1_2)
          ann_pp_prop = prop.type.property(ann_pp_attr)
          prop.type.create_integration_proxy_property(ann_pp_prop, pp_ip_prop)
        end
      end
    end
  end
end