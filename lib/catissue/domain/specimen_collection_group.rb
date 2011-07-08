require 'caruby/util/transitive_closure'
require 'caruby/util/validation'
require 'catissue/util/collectible'

module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.SpecimenCollectionGroup

  # The SpecimenCollectionGroup domain class.
  #
  # _Note_: the SpecimenCollectionGroup name attribute is auto-generated on create in caTissue 1.1 API and should not
  # be set by API clients when creating a new SpecimenCollectionGroup in the database.
  #
  # @quirk caTissue Bug #116: specimen_collection_site is incorrectly attached in the caTissue class
  #   model to AbstractSpecimenCollectionGroup rather than SpecimenCollectionGroup. CollectionProtocolEvent
  #   is a subclass of AbstractSpecimenCollectionGroup but does not have a collection site. Therfore, the
  #   specimen_collection_site is ignored in the caRuby AbstractSpecimenCollectionGroup class declaration
  #   and declared as an aliased, mandatory, fetched attribute for the SpecimenCollectionGroup subclass only.
  #
  # @quirk caTissue An auto-generated or created SCG auto-generates a ConsentTierStatus for each
  #   ConsentTierResponse defined in the SCG owner CPR.
  #
  # @quirk caTissue SCG consent_tier_statuses is cascaded but not fetched.
  #
  # @quirk caTissue SpecimenCollectionGroup auto-generated update ignores the referenced
  #   specimen_event_parameters and instead creates new parameters. This occurs only on the
  #   first update, and an SEP cannot be added to an existing, updated SCG. Work-around is
  #   to update the SCG template without the parameters, then update the parameters separately.
  #
  # @quirk caTissue although SpecimenCollectionGroup auto-generated update ignores referenced
  #   specimen_event_parameters, collection and received event parameters are mandatory for a
  #   a created SCG. Set the +:autogenerated_on_update_only+ flag rather than the +:autogenerate+
  #   to mark the attribute to handle this quirk.
  #
  # @quirk caTissue SCG specimens query result does not set the Specimen children and parent, even
  #   though they are guaranteed to be in the SCG specimens result set. The children and parent must be
  #   fetched separately, resulting in redundant copies of the same Specimen and additional fetches.
  #   caRuby partially rectifies this lapse by reconciling the SCG specimens parent-child relationships
  #   within the SCG scope.  class SpecimenCollectionGroup < CaTissue::AbstractSpecimenCollectionGroup
  #
  # @quirk caTissue caTissue requires that a SpecimenCollectionGroup update object references a
  #   CollectionProtocolRegistration with a Participant reference. This is a caTissue bug, since the
  #   CPR identifier should be sufficient for a SCG update, but caTissue bizlogic requires an extraneous
  #   CPR -> Participant reference. The work-around is too mark the attribute with a special
  #   +:include_in_save_template+ flag.
  #
  # @quirk caTissue Bug #65: Although SCG name uniquely identifies a SCG, the SCG name is auto-generated on create
  #   and cannnot be set by the client. Therefore, name is marked as update_only.
  #
  # @quirk caTissue Bug #64: Initialize the SCG consent_tier_statuses to an empty set.
  class SpecimenCollectionGroup
    include Collectible
    
    # @quirk caTissue Bug #64: Some domain collection properties not initialized.
    #   Initialize consent_tier_statuses if necessary.
    #
    # @return [Java::JavaUtil::Set] the statuses
    def consent_tier_statuses
      getConsentTierStatusCollection or (self.consent_tier_statuses = Java::JavaUtil::LinkedHashSet.new)
    end

    # Sets the collection status for this SCG.
    # If the SCG status is set to +Complete+, then the status of each of the SCG Specimens with
    # status +Pending+ is reset to +Collected+.
    #
    # @param [String] value a permissible SCG status
    def collection_status=(value)
      if value == 'Complete' then
        specimens.each { |spc| spc.collection_status = 'Collected' if spc.pending? }
      end
      setCollectionStatus(value)
    end

    # Converts an Integer SPN value to a String.
    #
    # @param [Numeric, String] value the SPN value
    def surgical_pathology_number=(value)
      value = value.to_s if Numeric === value
      setSurgicalPathologyNumber(value)
    end

    add_attribute_aliases(:collection_event => :collection_protocol_event,
      :event_parameters => :specimen_event_parameters,
      :events => :specimen_event_parameters,
      :registration => :collection_protocol_registration)

    add_mandatory_attributes(:specimen_collection_site, :clinical_diagnosis, :collection_status)
    
    qualify_attribute(:specimen_collection_site, :fetched)

    set_secondary_key_attributes(:name)

    set_alternate_key_attributes(:surgical_pathology_number, :collection_protocol_registration)

    add_dependent_attribute(:consent_tier_statuses, :autogenerated, :unfetched)

    # SCG event parameters are disjoint, since they are owned by either a SCG or a Specimen.
    # An auto-generated SCG also auto-generates the Collection and Received SEPs.
    # A SCG SEP is only created as a dependent when the SCG is created. A SCG SEP
    # cannot be created for an existing SCG. By contrast, a Specimen SEP can only be
    # created, not updated.
    add_dependent_attribute(:specimen_event_parameters, :autogenerated_on_update, :disjoint)

    # SCG Specimens are auto-generated from SpecimenRequirement templates when the SCG is created.
    # The Specimens are not cascaded.
    #
    add_dependent_attribute(:specimens, :logical, :autogenerated)

    # The CPE-SCG association is bi-directional.
    set_attribute_inverse(:collection_protocol_event, :specimen_collection_groups)

    # CPE is fetched but not cascaded.
    qualify_attribute(:collection_protocol_event, :fetched)

    qualify_attribute(:collection_protocol_registration, :include_in_save_template)

    qualify_attribute(:name, :autogenerated, :update_only)
    
    # The SCG proxy class.
    self.annotation_proxy_class_name = 'SCGRecordEntry'
    
    # The SCG pathology annotation.
    add_annotation('Pathology', :package => 'pathology_scg', :service => 'pathologySCG')

     def initialize
      super
      # work around caTissue Bug #64
      self.consent_tier_statuses ||= Java::JavaUtil::LinkedHashSet.new
    end

     # @return [CollectionProtocol] the SCG CPE CP
   def collection_protocol
      collection_protocol_event.collection_protocol if collection_protocol_event
    end

    # @return [Double, nil] the SCG CPE event point
    def event_point
      collection_protocol_event and collection_protocol_event.study_calendar_event_point
    end

    # @return [<SpecimenRequirement>] the SCG CPE requirements
    def requirements
      collection_protocol_event.nil? ? Array::EMPTY_ARRAY : collection_protocol_event.requirements
    end
    
    # @return [Boolean] whether this SCG collection status is one of the +Pending+ statuses.
    def pending?
      collection_status =~ /^Pending/
    end

    # Returns the number of specimens in this SpecimenCollectionGroup.
    def size
      specimens.size
    end

    # Removes associations to this registration.
    def delete
      registration.specimen_collection_groups.delete(self) if registration
    end

    # Merges the other object into this SpecimenCollectionGroup. This method augments
    # +CaRuby::Resource.merge_attributes+ as follows:
    # * Adds the transitive closure of each non-derived Specimen in other.
    #
    # @param (see CaRuby::Resource#merge_attributes)
    # @option (see Collectible#merge_attributes)
    def merge_attributes(other, attributes=nil)
      if Hash === other then
        # extract the event parameters
        other[:specimen_event_parameters] = extract_event_parameters(other)
        # take the transitive closure of the specimens
        spcs = other.delete(:specimens)
        if spcs then
          spcs = [spcs] if CaTissue::Specimen === spcs
          # take the transitive closure of the root specimens in the hierarchy
          other[:specimens] = spcs.select { |spc| spc.parent.nil? }.transitive_closure(:children)
        end
      end
      # delegate to super for standard attribute value merge
      super
    end

    def protocol
      collection_event.protocol if collection_event
    end

    # Returns whether this SCG is the same as the other SCG in the scope of an existing parent CPR.
    # This method returns whether the other SCG status is Pending and the event point is the
    # same as the other event point.
    def minimal_match?(other)
      super and event_point == other.event_point
    end

    # Overrides +CaRuby::Resource.direct_dependents+ in the case of the _specimens_ attribute to select
    # only top-level Specimens not derived from another Specimen.
    def direct_dependents(attribute)
      if attribute == :specimens then
        super.reject { |spc| spc.parent }
      else
        super
      end
    end
    
    CONSENT_TIER_STATUS_ATTRS = [:consent_tier_statuses]
    
    def mandatory_attributes
      attrs = super
      if registration and not registration.consent_tier_responses.empty? then
        attrs + CONSENT_TIER_STATUS_ATTRS
      else
        attrs
      end
    end

    # Relaxes the +CaRuby::Persistable.saved_fetch_attributes+ condition for a SCG as follows:
    # * If the SCG status was updated from +Pending+ to +Collected+, then fetch the saved SCG event parameters.
    # 
    # @param (see CaRuby::Persistable#saved_fetch_attributes)
    # @return (see CaRuby::Persistable#saved_fetch_attributes)
    def saved_fetch_attributes(operation)
      operation == :update && status_changed_to_complete? ? EVENT_PARAM_ATTRS : super
    end
    
    # Relaxes the +CaRuby::Persistable.saved_fetch_attributes+ condition for a SCG as follows:
    # * If the SCG status was updated from +Pending+ to +Collected+, then fetch the saved SCG event parameters.
    # 
    # @param (see CaRuby::Persistable#saved_fetch_attributes)
    # @return (see CaRuby::Persistable#saved_fetch_attributes)
    def autogenerated?(operation)
      operation == :update && status_changed_to_complete? ? EVENT_PARAM_ATTRS : super
    end

    private
    
    EVENT_PARAM_ATTRS = [:specimen_event_parameters]

    def validate_local
      super
      validate_consent
      validate_event_parameters
    end
    
    # @see #fetch_saved
    def status_changed_to_complete?
      if collected? and snapshot and snapshot[:collection_status] == 'Pending' then
        logger.debug { "Saved #{qp} event parameters must be fetched from the database to reflect the current database state, since the status was changed from Pending to Complete." }
        true
      else
        false
      end
    end

    # Adds defaults as follows:
    # * The default collection event is the first event in the protocol registered with this SCG.
    # * The default collection status is 'Complete' if there is a received event, 'Pending' otherwise.
    # * The default collection site is the CP site, if this SCG is {#received?} and there is only CP one,
    #   otherwise the {CaTissue::Site.default_site}.
    # * The default conset tier status is 'Complete' if there is a received event, 'Pending' otherwise.
    # * A default ReceivedEventParameters is added to this SCG if the collection status is
    #   'Complete' and there is no other ReceivedEventParameters. The receiver is an arbitrary
    #   protocol coordinator.
    #
    # @raise [ValidationError] if the default ReceivedEventParameters could not be created because
    #   there is no protocol or protocol coordinator
    # @see CollectionProtocol#first_event
    def add_defaults_local
      super
      # the default event
      self.collection_protocol_event ||= default_collection_event

      # the default collection status and received parameters
      if received? then
        self.collection_status ||= 'Complete'
      else
        self.collection_status ||= 'Pending'
        create_default_received_event_parameters
      end
      # the default collection event
      unless collected? then
        create_default_collection_event_parameters
      end

      # the default site
      self.collection_site ||= default_site
      
      # the default CT statuses
      make_default_consent_tier_statuses
    end
    
    # Makes a consent status for each registration consent.
    #
    # @quirk caTissue Bug #156: SCG without consent status displays error.
    #   A SCG consent tier status is required for each consent tier in the SCG registration.
    def make_default_consent_tier_statuses
      return if registration.nil? or registration.consent_tier_responses.empty?
      
      # the consent tiers
      ctses = consent_tier_statuses.map { |cts| cts.consent_tier }
      # ensure that there is a CT status for each consent tier
      registration.consent_tier_responses.each do |ctr|
        ct = ctr.consent_tier
        # skip if there is a status for the response tier
        next if ctses.include?(ct)
        # make a new status
        cts = CaTissue::ConsentTierStatus.new(:consent_tier => ct)
        cts.add_defaults
        consent_tier_statuses << cts
        logger.debug { "Made default #{qp} #{cts.qp} for consent tier #{ct.qp}." }
      end
    end

    def default_site
      return if collection_event.nil?
      cp = collection_event.protocol || return
      site = cp.default_site || return
      logger.debug { "Default #{qp} site is #{site}." }
      site
    end

    # Returns the first event in the protocol registered with this SCG.
    def default_collection_event
      return if registration.nil?
      pcl = registration.protocol || return
      # if no protocol event, then add the default event
      pcl.add_defaults if pcl.events.empty?
      ev = pcl.first_event || return
      logger.debug { "Default #{qp} collection event is the registration protocol #{pcl.qp} first event #{ev.qp}." }
      ev
    end

    def create_default_received_event_parameters
      cp = collection_protocol
      if cp.nil? then
        raise ValidationError.new("SCG with status Complete default CollectionEventParameters could not be created since there is no collection protocol: #{self}")
      end
      rcvr = cp.coordinators.first
      if rcvr.nil? then
        raise ValidationError.new("SCG with status Complete default CollectionEventParameters could not be created since there is no collection protocol coordinator: #{self}")
      end
      # make the REP
      ev = CaTissue::SpecimenEventParameters.create_parameters(:received, self, :user => rcvr)
      ev.add_defaults_recursive
      logger.debug { "Made default #{qp} received event parameter #{ev.qp}." }
      ev
    end

    def create_default_collection_event_parameters
      rep = received_event_parameters || return
      # make the CEP from the REP
      ev = CaTissue::SpecimenEventParameters.create_parameters(:collection, self, :user => rep.user, :timestamp => rep.timestamp)
      ev.add_defaults_recursive
      logger.debug { "Made default #{qp} collected event parameter #{ev.qp}." }
      ev
    end

    # @raise [ValidationError] if there is a registration consent tier response without a corresponding SCG consent tier status
    def validate_consent
      return unless registration
      # the default consent statuses
      ctses = consent_tier_statuses.map { |cts| cts.consent_tier }
      registration.consent_tier_responses.each do |ctr|
        ct = ctr.consent_tier
        unless ctses.include?(ct) then
          raise ValidationError.new("#{self} is missing a ConsentTierStatus for consent statement #{ct.statement}")
        end
      end
    end

    # @raise [ValidationError] if the SCG has neither an identifier nor Received and Collection event parameters
    def validate_event_parameters
      if identifier.nil? and event_parameters.empty? then
        raise ValidationError.new("#{self} create is missing the required Received and Collection event parameters")
      end
    end
  end
end