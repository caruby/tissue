require 'set'
require 'jinx/helpers/collections'

require 'jinx/helpers/partial_order'
require 'catissue/annotation/annotation'
require 'catissue/annotation/proxy_1_1'
require 'catissue/annotation/record_entry_proxy'

module CaTissue
  module Annotation
    # Annotation hook proxy class mix-in.
    module ProxyClass
      # @return [CaRuby::Property] the hook class attribute meta-data for this proxy
      attr_reader :hook_property
      
      # @param [Class] klass the proxy class
      def self.extended(klass)
        super
        # distinguish the 1.1 from the 1.2 proxy class
        mixin = klass.name =~ /RecordEntry$/ ? RecordEntryProxy : Proxy_1_1
        klass.class_eval { include mixin }
      end
      
      # @return [Metadata] the hook class for this proxy
      def hook
        hook_property.type
      end
      
      # Sets this proxy's hook to the given class and creates the
      # proxy => hook attribute with the given hook => proxy inverse.
      #
      # @param [Metadata] klass the annotated domain object class
      # @return [Class] the given hook class
      def hook=(klass)
        @hook_property = obtain_hook_property(klass)
        logger.debug { "#{self} -> #{klass.qp} annotation proxy => hook attribute: #{@hook_property}." }
        klass
      end
      
      # Adds each proxy => annotation reference as a dependent attribute.
      # Recursively adds dependents of all referenced annotations.
      #
      # This method defines a proxy attribute in each primary annotation class
      # for each {#non_proxy_annotation_classes} class hierarchy.
      def build_annotation_dependency_hierarchy 
        # Each primary must reference this proxy.
        logger.debug { "Building the #{annotation_module.qp} annotation proxy #{self} dependency hierarchy..." }
        ensure_primary_annotations_reference_proxy
        set_inverses
        add_dependent_attributes
        add_dependent_attribute_closure
      end
      
      # Defines a proxy attribute in each primary annotation class for each
      # {#non_proxy_annotation_classes} class hierarchy.
      def ensure_primary_annotations_reference_proxy
        non_proxy_annotation_classes.each do |klass|
          ensure_primary_references_proxy(klass)
        end
      end
      
      # Creates a reference property from this proxy to the given primary {Annotation} class. 
      #
      # @param [Class] klass the target annotation class
      # @return [Symbol] the new annotation reference attribute
      def create_annotation_property(klass)
        # the new attribute symbol
        pa = klass.name.demodulize.underscore.pluralize.to_sym
        logger.debug { "Creating the annotation proxy #{qp} attribute #{pa} to hold the primary annotation #{klass.qp} instances..." }
        # Define the access methods: the reader creates a new set on demand to hold the annotations.
        attr_create_on_demand_accessor(pa) { Set.new }
        # add the annotation collection attribute
        add_attribute(pa, klass, :collection)
        logger.debug { "Created the #{self} -> #{klass} annotation proxy dependent attribute #{pa}." }
        pa
      end
      
      # @quirk caTissue 2.0 The RecordEntry annotation proxy classes in 2.0 added
      #   a reference property to the form context, which further pollutes the data
      #   layer with presentation artifacts. caRuby excludes this property
      #   from the {#annotation_attributes} since it interferes with determining
      #   the true annotation data hierarchy.
      def annotation_attributes
        @pxy_ann_attrs ||= super.compose { |prop| prop.attribute != :form_context }
      end
      
      private
      
      # Ensures that the given primary class references this proxy.
      #
      # @param [Metadata] klass the primary annotation class to check
      def ensure_primary_references_proxy(klass)
        # Define the superclass proxy attributes, starting with the most general class.
        klass.annotation_hierarchy.to_a.reverse_each do |anc|
          if anc.entity_primary? and not anc.primary? then
            anc.proxy_property_for(self)
          end
        end
      end
    
      # Sets each annotation reference attribute inverse to the direct, unwrapped proxy
      # reference named by the annotation module. E.g. the caTissue +Participant+
      # +clinical+ proxy +ParticipantRecordEntry+ -> +NewDiagnosisAnnotation+ attribute
      # inverse is set to the +NewDiagnosisAnnotation+ -> +ParticipantRecordEntry+
      # +clinical+ reference attribute.
      def set_inverses
        return if annotation_attributes.empty?
        # The primary annotation properties in class hierarchy general-to-specific order.
        props = annotation_attributes.properties.partial_sort_by { |prop| prop.type }.reverse
        logger.debug { "Setting the #{self} inverses for annotation attributes #{props.to_series}." }
        props.each do |prop|
          # The inverse property is the proxy reference. Create one, if necessary.
          ip = prop.type.proxy_property_for(self)
          set_attribute_inverse(prop.to_sym, ip.attribute)
        end
      end
      
      def obtain_hook_property(klass)
        prop = domain_properties.detect { |p| klass == p.type }
        return prop if prop
        # Make the hook class reference property.
        pa = klass.name.demodulize.underscore
        attr_accessor(pa)
        add_attribute(pa, klass)
      end
      
      # @return <Metadata> the non-proxy annotation classes
      def non_proxy_annotation_classes
        annotation_module.annotation_classes.filter { |klass| not klass < Proxy }
      end
    end
  end
end
