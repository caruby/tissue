module CaTissue
  module Annotation
    # This IntegrationMetadata mix-in extends the domain RecordEntry classes with methods
    # that tie together the hook and its annotations.
    module IntegrationMetadata
      include CaRuby::Metadata
      
      # @return [Module] the annotation module integrated by this class
      attr_reader :annotation_module
       
      # Integrates the given hook class and annotation module.
      # 
      # @quirk caTissue 1.2 The caTissue 1.2 RecordEntry annotation proxy classes
      #   have a proxy proxy in the annotation package. This adds yet another level
      #   of indirection from the static domain class to the DE annotations, e.g.:
      #     Specimen -> integration SpecimenRecordEntry -> pathology SpecimenRecordEntry -> ProstateSpecimenPathologyAnnotation
      #   caRuby hides this Byzantine complexity by injecting integration RecordEntry
      #   helper methods to the target annotation class, e.g.:
      #     integration SpecimenRecordEntry -> ProstateSpecimenPathologyAnnotation
      #   that compose the integration proxy -> annotation proxy -> target annotation
      #   methods.
      #
      # @quirk caTissue 2.0 The RecordEntry annotation proxy classes in 2.0 added
      #   a reference property to the form context, which further pollutes the data
      #   layer with presentation artifacts. caRuby excludes this property
      #   from the {#annotation_attributes} since it interferes with determining
      #   the true annotation data hierarchy.
      #
      # @param [Class] hook the hook class
      # @param [Module] mod the annotation module
      def integrate(mod)
        @annotation_module = mod
        unless CaTissue::Database.current.uniform_application_service? then
          extend(IntegrationMetadata_1_2)
          integrate_proxy_proxy(mod)
        end
        # 1.2 has a proxy proxy in the  
        # Select the dependent properties. A property is dependent if its
        # type is in the given annotation module.
        dps = properties.select { |prop| mod.contains?(prop.type) }
        # Sort the properties so that a superclass dependent is added before
        # a subclass dependent. The sort criteria is the property return type
        # class hierarchy relationship. The partial sort places  property types are not comparable,
        # then the order is indeterminate. The properties
        # are sorted in order to accurately distinguish an annotation subclass
        # reference to this proxy class from a superclass reference to this proxy
        # class. Adding the superclass dependent first sets the superclass
        # owner property inverse. Thus, when the subclass dependent is subsequently
        # added, there are two candidate owner properties, but the superclass
        # owner property is disqualified since its inverse is already set.
        dps.partial_sort! { |p1, p2| p2.type <=> p1.type }
        logger.debug { "Adding #{qp} #{mod.qp} annotation dependents #{dps.to_series}..." } unless dps.empty?
        # Set the dependent -> proxy properties on demand.
        dps.each do |prop|
          pxy_prop = prop.type.proxy_property_for(self)
          logger.debug { "Added #{@annotation_module.qp} proxy #{qp} dependent primary annotation #{prop.type.qp} with proxy reference #{pxy_prop}." }
        end
        # Define the dependents.
        dps.each do |prop|
          add_dependent_hierarchy(prop)
          # pre-2.0 annotations are logical dependents.
          unless CaTissue::Database.current.uniform_application_service? then
            qualify_attribute(prop, :logical)
          end
        end
        # Add a hook convenience method.
        alias_method(:hook, hook_property.attribute)
        logger.debug { "Aliased #{qp} #{hook_property} with the the hook method" }
      end
            
      alias :hook_property :owner_property
      
      alias :hook_type :owner_type
      
      alias :annotation_attributes :dependent_attributes
      
      private
      
      # Defines non-cyclic annotation references as dependents.
      def add_dependent_hierarchy(property)
        visitor = Jinx::Visitor.new(:prune_cycles) do |prop|
          # The non-owner independent annotation reference types.
          prop.type.properties.select do |p|
            p.independent? and p.type < Annotation and not p.type.primary? and not p.owner?
          end
        end
        visitor.visit(property) do |prop|
          prop.declarer.add_dependent_property(prop) unless prop.dependent?
          logger.debug { "Defined the annotation #{prop.declarer.qp} dependent #{prop}." }
        end
      end
    end
  end
end
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 