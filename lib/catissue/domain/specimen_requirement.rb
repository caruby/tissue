require 'jinx/helpers/validation'

module CaTissue
  # The SpecimenRequirement domain class.
  class SpecimenRequirement
    # @quirk caTissue SpecimenRequirement specimens property is unnecessary and prohibitively
    #   expensive to load on demand. 
    remove_attribute(:specimens)

    add_attribute_aliases(:collection_event => :collection_protocol_event)

    add_attribute_defaults(
      :initial_quantity => 0.0,
      :pathological_status => 'Not Specified',
      :specimen_type => 'Not Specified',
      :storage_type => 'Not Specified')

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
    
    # The preferred owner attribute evaluation order is the parent specimen, then the CPE.
    order_owner_attributes(:parent_specimen, :collection_protocol_event)
    
    # @return [Boolean] false
    def updatable?
      false
    end
    
    # Returns the SpecimenRequirement in _others_ which matches this SpecimenRequirement
    # in the scope of an owner CollectionProtocolEvent. This method relaxes
    # +Jinx::Resource.match_in_owner_scope+ for a SpecimenRequirement that matches any
    # SpecimenRequirement in others with the same class, specimen type, pathological_status
    # and characteristics.
    def match_in_owner_scope(others)
      others.detect do |other|
        self.class == other.class and specimen_type == other.specimen_type and pathological_status == other.pathological_status and
         characteristics and characteristics.matches?(other.characteristics)
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

    # @return [CaTissue::CollectionProtocol] the collection event protocol, if any
    def collection_protocol
      collection_event.protocol if collection_event
    end

    protected

    # @quirk caTissue Overrides the Jinx::Resource method to handle caTissue Bug #67 -
    #   SpecimenRequirement activityStatus cannot be set.
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

    # Augments +Jinx::Resource.validate+ to verify that this SpecimenRequirement does not have multiple
    # non-aliquot derivatives, which is disallowed by caTissue.
    #
    # @quirk caTissue multiple SpecimenRequirement non-aliquot derivatives is accepted by caTissue but results
    #   in obscure downstream errors (cf. Bug #151).
    #
    # @raise [Jinx::ValidationError] if this SpecimenRequirement has multiple non-aliquot derivatives
    def validate_local
      super
      if multiple_derivatives? then raise Jinx::ValidationError.new("Multiple derivatives not supported by caTissue") end
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