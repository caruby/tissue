require 'caruby/util/validation'

module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.SpecimenRequirement

  # The SpecimenRequirement domain class.
  class SpecimenRequirement < CaTissue::AbstractSpecimen
    # @quirk caTissue Bug #64: Some domain collection properties not initialized.
    #   Initialize specimens if necessary. 
    #
    # @return [Java::JavaUtil::Set] the specimens
   def specimens
      getSpecimenCollection or (self.specimens = Java::JavaUtil::LinkedHashSet.new)
    end

    add_attribute_aliases(:collection_event => :collection_protocol_event)

    add_attribute_defaults(:initial_quantity => 0.0, :pathological_status => 'Not Specified', :specimen_type => 'Not Specified', :storage_type => 'Not Specified')

    add_mandatory_attributes(:collection_protocol_event, :storage_type)

    # SpecimenRequirement children are constrained to SpecimenRequirement.
    set_attribute_type(:child_specimens, SpecimenRequirement)

    # SpecimenRequirement parent is constrained to SpecimenRequirement.
    set_attribute_type(:parent_specimen, SpecimenRequirement)

    # As with Specimen, even though the inverse is declared in AbstractSpecimen, do so
    # again here to ensure that there is no order dependency of the dependent declaration
    # below on AbstractSpecimen metadata initialization.
    set_attribute_inverse(:parent_specimen, :child_specimens)

    # Unlike Specimen, a child SpecimenRequirement is not cascaded by caTissue.
    # It is not auto-generated, i.e. it is not created from a template when the
    # parent CPE is created.
    qualify_attribute(:child_specimens, :logical)
    
    # Overrides {Resource#owner} to return the parent_specimen, if it exists, or the collection_protocol_event otherwise.
    def owner
      parent_specimen or collection_protocol_event
    end
    
    # Returns the SpecimenRequirement in others which matches this SpecimenRequirement in the scope of an owner CollectionProtocolEvent.
    # This method relaxes {CaRuby::Resource#match_in_owner_scope} for a SpecimenRequirement that matches any SpecimenRequirement
    # in others with the same class, specimen type, pathological_status and characteristics.
    def match_in_owner_scope(others)
      others.detect do |other|
        self.class == other.class and specimen_type == other.specimen_type and pathological_status == other.pathological_status and
         characteristics and characteristics.match?(other.characteristics)
      end
    end

    private
    
    # Returns whether this SpecimenRequirement characteristics matches the other SpecimenRequirement characteristics
    # on the tissue site and tissue side.
    def match_characteristics(other)
      chr = characteristics
      ochr = other.characteristics
      chr and ochr and chr.tissue_side == ochr.tissue_side and chr.tissue_site == ochr.tissue_site
    end

    # Raises NotImplementedError, since SpecimenRequirement is abstract.
    def self.allocate
      raise NotImplementedError.new("SpecimenRequirement is abstract; use the create method to make a new instance")
    end

    public

    # @quirk caTissue Bug #64 - consent tier responses is not initialized to an empty set
    #    in the Java constructor. Initialize it to a +LinkedHashSet+ in caRuby.
    def initialize
      super
      # @quirk JRuby specimens property method is not accessible until respond_to? is called.
      respond_to?(:specimens)
      self.specimens ||= Java::JavaUtil::LinkedHashSet.new
    end

    # Creates a SpecimenRequirement of the given subclass type for the given CollectionProtocolEvent event.
    # The type is a SpecimenRequirement subclass name without the +SpecimenRequirement+ suffix, e.g.
    # +Tissue+. Lower-case, underscore symbols are supported and preferred, e.g. the
    # :tissue type creates a TissueSpecimenRequirement.
    #
    # The optional params argument are attribute => value associations, e.g.
    #   SpecimenRequirement.create_requirement(:tissue, event, :specimen_type => 'RNA')
    def self.create_requirement(type, event, params=Hash::EMPTY_HASH)
      # make the class name by joining the camel-cased type prefix to the subclass suffix
      class_name = type.to_s.classify + self.qp
      begin
        klass = CaTissue.const_get(class_name)
      rescue
        raise ArgumentError.new("Unsupported requirement type: #{type}; #{class_name} must be a subtype of #{self}")
      end
      klass.new(params.merge(:collection_protocol_event => event))
    end

    # Returns the {#collection_event} protocol, if any.
    def collection_protocol
      collection_event.protocol if collection_event
    end

    protected

    # @quirk caTissue Overrides the CaRuby::Resource method to handle caTissue Bug #67 - SpecimenRequirement activityStatus cannot be set.
    #
    # @return [<Symbol>] the required attributes which are nil for this domain object
    def missing_mandatory_attributes
      invalid = super
      if invalid.include?(:activity_status) then
        invalid.delete(:activity_status)
      end
      # end of workaround
      invalid
    end

    private

    # Returns whether this SpecimenRequirement has multiple non-aliquot derivatives.
    def multiple_derivatives?
      children.size > 1 and children.any? { |drv| not drv.aliquot? }
    end

    # Augments {CaRuby::Resource#validate} to verify that this SpecimenRequirement does not have multiple non-aliquot
    # derivatives, which is disallowed by caTissue.
    #
    # @quirk caTissue multiple SpecimenRequirement non-aliquot derivatives is accepted by caTissue but results
    #   in obscure downstream errors (cf. Bug #151).
    #
    # @raise [ValidationError] if this SpecimenRequirement has multiple non-aliquot derivatives
    def validate_local
      super
      if multiple_derivatives? then raise ValidationError.new("Multiple derivatives not supported by caTissue") end
    end

    # Adds the following default values, if necessary:
    # * a generic SpecimenCharacteristics
    # * the parent collection_event, if this SpecimenRequirement is derived
    def add_defaults_local
      super
      self.collection_event ||= parent.collection_event if parent
      self.specimen_characteristics ||= CaTissue::SpecimenCharacteristics.new
    end
  end
end