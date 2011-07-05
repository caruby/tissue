require 'set'
require 'caruby/util/collection'
require 'caruby/util/partial_order'
require 'catissue/annotation/annotation'
require 'catissue/annotation/proxy_1_1'
require 'catissue/annotation/record_entry_proxy'

module CaTissue
  module Annotation
    # Annotation hook proxy class mix-in.
    module ProxyClass
      # @param [Class] klass the proxy class
      def self.extended(klass)
        super
        # distinguish the 1.1 from the 1.2 proxy class
        mixin = klass.name =~ /RecordEntry$/ ? RecordEntryProxy : Proxy_1_1
        klass.class_eval { include mixin }
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
        non_proxy_annotation_classes.each do |klass|
          klass.annotation_hierarchy.each do |anc|
            if anc.primary? and anc.proxy_attribute.nil? then
              anc.define_proxy_attribute(self)
            end
          end
          logger.info(klass.pp_s)
        end
        set_inverses
        add_dependent_attributes
        add_dependent_attribute_closure
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
        attr
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
        # The attributes in class hierarchy general-to-specific order
        attr_mds = annotation_attributes.enum_metadata.partial_sort_by { |attr_md| attr_md.type }.reverse
        logger.debug { "Setting #{self} inverses for annotation attributes #{attr_mds.to_series}." }
        attr_mds.each do |attr_md|
          attr_md.type.define_proxy_attribute(self)
          set_attribute_inverse(attr_md.to_sym, inv)
        end
      end
      
      # @return <AnnotationClass> the non-proxy annotation classes
      def non_proxy_annotation_classes
        consts = annotation_module.constants.map { |s| annotation_module.const_get(s) }
        consts.select { |c| Class === c and c < Annotation and not c < Proxy }
      end
    end
  end
end
