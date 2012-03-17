require 'jinx/helpers/collections'

require 'catissue/helpers/hash_code'

module CaTissue
  # The CollectionProtocolEvent domain class.
  class CollectionProtocolEvent
    include HashCode
    
    # @quirk caTissue Bug #64: Some domain collection properties not initialized.
    #    Initialize specimen_collection_groups if necessary.
    #
    # @return [Java::JavaUtil::Set] the SCGs
    def specimen_collection_groups
      getSpecimenCollectionGroupCollection or (self.specimen_collection_groups = Java::JavaUtil::LinkedHashSet.new)
    end

    add_attribute_aliases(:label => :collection_point_label,
      :protocol => :collection_protocol,
      :requirements => :specimen_requirements,
      :event_point => :study_calendar_event_point)

    # CPE secondary key is the CP and collection point.
    set_secondary_key_attributes(:collection_protocol, :collection_point_label)

    # CPE alternate key is the CP and event point.
    set_alternate_key_attributes(:collection_protocol, :study_calendar_event_point)

    # Default event point is day one.
    add_attribute_defaults(:study_calendar_event_point => 1.0)

    add_mandatory_attributes(:collection_protocol, :clinical_diagnosis, :specimen_requirements)

    # @quirk caTissue specimen_requirements is a cascaded dependent, but it is not fetched.
    #   CollectionProtocol create cascades through each dependent CPE to each SpecimenRequirement.
    add_dependent_attribute(:specimen_requirements, :unfetched)

    # @quirk caTissue The +specimen_collection_groups+ is unnecessary and expensive to maintain inverse integrity.
    #    The SCG event attribute is required, but adding the SCG to the event SCG inverse attribute value requires
    #    loading all of the SCGs. +specimen_collection_groups+ is not used in practice. The event SCGs can be
    #    easily obtained by a query.
    remove_attribute(:specimen_collection_groups)

    # The event point used for saving this CollectionProtocolEvent if none other is set.
    DEFAULT_EVENT_POINT = 1.0

    # Removes associations to this registration
    def delete
      protocol.events.delete(self) if protocol
    end

    # Overrides +Jinx::Resource.references+ in the case of the _specimen_requirements_ attribute to select
    # only top-level SpecimenRequirements not derived from another SpecimenRequirement.
    def direct_dependents(attribute)
      if attribute == :specimen_requirements then
        super.reject { |spc| spc.parent }
      else
        super
      end
    end

    private

    # Sets the default label to the protcol name followed by the event point.
    def add_defaults_local
      super
      self.label ||= default_label
    end

    def default_label
      pcl = protocol_label_component
      if pcl and event_point then
        "#{pcl}_#{event_point}"
      end
    end
    
    def protocol_label_component
      return if protocol.nil?
      pcl = protocol.short_title || protocol.title || return
      pcl.sub(' ', '_')
    end
  end
end