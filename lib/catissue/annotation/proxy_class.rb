require 'set'
require 'catissue/annotation/annotation'
require 'catissue/annotation/proxy'

module CaTissue
  module Annotation
    # Annotation hook proxy class mix-in.
    module ProxyClass
      # @return [AnnotatableClass] the hook class for this proxy
      attr_reader :hook
      
      # @param [Class] klass the proxy class
      def self.extended(klass)
        super
        klass.class_eval { include Proxy }
      end
      
      def annotation_attributes
        @ann_attrs ||= domain_attributes.compose { |attr_md| attr_md.type < Annotation }
      end

      # Sets this proxy's hook to the given class. 
      # Creates the proxy => hook attribute with the given hook => proxy inverse.
      #
      # @param [Class] klass the hook class
      # @param [Symbol] inverse the hook class hook => proxy attribute
      def set_hook(klass, inverse)
        @hook = klass
        # Make a new hook reference attribute.
        attr_accessor(:hook)
        # The attribute type is the given hook class.
        add_attribute(:hook, klass)
        # Setting one end of the hook <-> proxy association sets the other end.
        set_attribute_inverse(:hook, inverse)
        logger.debug { "Added #{klass.qp} annotation proxy => hook attribute with inverse #{klass.qp}.#{inverse}." }
      end
      
      # Adds each proxy => annotation reference as a dependent attribute.
      def add_annotation_dependents
        # first add the direct dependents
        annotation_attributes.each_metadata do |attr_md|
          attr_md.type.add_dependent_attributes
        end
        # now add the recursive indirect dependents
        annotation_attributes.each_metadata do |attr_md|
          attr_md.type.add_dependent_attribute_closure
        end
      end
      
      # Creates a reference attribute from this proxy to the given primary {Annotation} class. 
      #
      # @param [Class] klass the annotation class
      # @param [Symbol] inverse the annotation => proxy attribute
      def create_annotation_attribute(klass, inverse)
        # the new attribute symbol
        attr = klass.name.demodulize.underscore.pluralize.to_sym
        logger.debug { "Creating annotation proxy #{qp} attribute #{attr} to hold primary annotation #{klass.qp} instances..." }
        # Define the access methods: the reader creates a new set on demand to hold the annotations.
        attr_create_on_demand_accessor(attr) { Set.new }
        # add the annotation collection attribute
        add_attribute(attr, klass, :collection)
        # make the hook attribute which delegates to this proxy
        @hook.create_annotation_attribute(domain_module, attr)
        # set the attribute inverse
        set_attribute_inverse(attr, inverse)
      end
    end
  end
end
