require 'caruby/util/collection'

module CaTissue
  # import the Java class
  java_import('edu.wustl.catissuecore.domain.CollectionProtocolEvent')

  # The CollectionProtocolRegistration domain class.
  class CollectionProtocolEvent
    include Resource
    
    # caTissue alert - Bug #64: Some domain collection properties not initialized.
    # Initialize specimen_collection_groups if necessary.
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

    # caTissue alert - specimen_requirements is a cascaded dependent, but it is not fetched.
    # CollectionProtocol create cascades through each dependent CPE to each SpecimenRequirement.
    add_dependent_attribute(:specimen_requirements, :unfetched)

    # The event point used for saving this CollectionProtocolEvent if none other is set.
    DEFAULT_EVENT_POINT = 1.0

    def initialize(params=nil)
      super
      respond_to?(:specimen_collection_groups)
      # work around caTissue Bug #64
      self.specimen_collection_groups ||= Java::JavaUtil::LinkedHashSet.new
    end

    # Overrides the Java CollectionProtocolEvent hashCode to make the hash insensitive to identifier assignment.
    def hash
      # caTissue alert - caTissue determines the hashCode from the identifier. Consequently, a CollectionProtocolEvent
      # added to a HashSet without an identifier can no longer find the CPE when it is assigned an identifier.
      # This bug results in obscure delayed cascade errors. Work-around is to override the hash method in the
      # Ruby CPE wrapper class.
      (object_id * 31) + 17
    end

    # Returns whether other is a CollectionProtocolEvent with the same identifier as this CollectionProtocolEvent,
    # or the same object_id if this CollectionProtocolEvent's identifier is nil.
    #
    # This method is a work-around for caTissue bug: CollectionProtocolEvent and non-CollectionProtocolEvent are equal in caTissue 1.1.
    def ==(other)
      object_id == other.object_id
    end

    alias :eql? :==

    # Removes associations to this registration
    def delete
      protocol.events.delete(self) if protocol
    end

    # Overrides {CaRuby::Resource#references} in the case of the _specimen_requirements_ attribute to select
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
      "#{protocol.short_title.sub(' ', '_')}_#{event_point}" if protocol and protocol.short_title and event_point
    end
  end
end