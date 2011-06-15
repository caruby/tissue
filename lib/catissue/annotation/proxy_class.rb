require 'set'
require 'caruby/util/collection'
require 'catissue/annotation/annotation'
require 'catissue/annotation/proxy'

module CaTissue
  module Annotation
    # Annotation hook proxy class mix-in.
    module ProxyClass
      # @param [Class] klass the proxy class
      def self.extended(klass)
        super
        klass.class_eval { include Proxy }
      end
      
      def annotation_attributes
        @ann_attrs ||= infer_annotation_attributes
      end
      
      # @return [AnnotatableClass] the hook class for this proxy
      def hook
        owner_type
      end
      
      # Sets this proxy's hook to the given class and creates the
      # proxy => hook attribute with the given hook => proxy inverse.
      #
      # @param [AnnotatableClass] klass the annotated domain object class
      def hook=(klass)
        # Make a new hook reference attribute.
        attr = klass.name.demodulize.underscore
        attr_accessor(attr)
        # The attribute type is the given hook class.
        add_attribute(attr, klass)
        logger.debug { "Added #{klass.qp} annotation proxy => hook attribute #{attr}." }
      end
      
      # Adds each proxy => annotation reference as a dependent attribute.
      # Recursively adds dependents of all referenced annotations.
      def build_annotation_dependency_hierarchy
        logger.debug { "Building annotation dependency hierarchy..." }
        set_inverses
        add_dependent_attributes
        add_dependent_attribute_closure
      end
      
      # @param [Class] klass the target annotation attribute type
      def obtain_annotation_attribute(klass)
        detect_annotation_attribute(klass) or create_annotation_attribute(klass)
      end

      private
    
      # Sets each annotation reference attribute inverse to the direct, unwrapped proxy
      # reference named by the annotation module. E.g. the caTissue +Participant+
      # +clinical+ proxy +ParticipantRecordEntry+ -> +NewDiagnosisAnnotation+ attribute
      # inverse is set to the +NewDiagnosisAnnotation+ -> +ParticipantRecordEntry+
      # +clinical+ reference attribute.
      def set_inverses
        # The inverse is the direct, unwrapped proxy reference named by the annotation module.
        inv = annotation_module.name.demodulize.underscore.to_sym
        annotation_attributes.each_metadata do |attr_md|
          attr_md.type.define_proxy_attribute(self)
          set_attribute_inverse(attr_md.to_sym, inv)
        end
      end
    
      # @param [Class] klass the target annotation attribute type
      # @return [Symbol, nil] the proxy => primary annotation dependent attribute, if any
      def detect_annotation_attribute(klass)
        attr = dependent_attribute(klass)
        return attr if attr
        # Not dependent; if it is a non-dependent, then make it dependent.
        attr = detect_attribute_with_type(klass)
        if attr then
          logger.debug { "Adding annotation reference #{attr} to #{klass.qp} as a dependent..." }
          add_dependent_attribute(attr, :logical)
        end
        attr
      end
      
      # Creates a reference attribute from this proxy to the given primary {Annotation} class. 
      #
      # @param [Class] klass the annotation class
      def create_annotation_attribute(klass)
        # the new attribute symbol
        attr = klass.name.demodulize.underscore.pluralize.to_sym
        logger.debug { "Creating annotation proxy #{qp} attribute #{attr} to hold primary annotation #{klass.qp} instances..." }
        # Define the access methods: the reader creates a new set on demand to hold the annotations.
        attr_create_on_demand_accessor(attr) { Set.new }
        # add the annotation collection attribute
        add_attribute(attr, klass, :collection)
        # The annotation is dependent.
        add_dependent_attribute(attr, :logical)
#        # make the hook attribute which delegates to this proxy
#        @hook.create_annotation_attribute(domain_module, attr)
        attr
      end
      
      def infer_annotation_attributes
#        # Infer the domain attributes first. Do so with a copy of the attribute metadata objects
#        # since the domain type inference can result in adding a new annotation attribute.
#        attribute_metadata_hash.values.each { |attr_md| attr_md.domain? }
        domain_attributes.compose { |attr_md| attr_md.type < Annotation }
      end
    end
  end
end
