require 'jinx/helpers/transitive_closure'
require 'jinx/helpers/validation'
require 'catissue/helpers/collectible'

module CaTissue
  # The SpecimenCollectionGroup domain class.
  #
  # _Note_: the SpecimenCollectionGroup name attribute is auto-generated on create in caTissue 1.1 API and should not
  # be set by API clients when creating a new SpecimenCollectionGroup in the database.
  class SpecimenCollectionGroup
    include Collectible
    
    # @quirk caTissue Bug #64: Some domain collection properties not initialized.
    #   Initialize consent_tier_statuses if necessary.
    #
    # @return [Java::JavaUtil::Set] the statuses
    def consent_tier_statuses
      ctss = getConsentTierStatusCollection
      ctss ||= self.consent_tier_statuses = Java::JavaUtil::LinkedHashSet.new
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

    add_attribute_aliases(:collection_event => :collection_protocol_event,
      :event => :collection_protocol_event,
      :event_parameters => :specimen_event_parameters,
      :spn => :surgical_pathology_number,
      :registration => :collection_protocol_registration
    )

    # @quirk caTissue Bug #116: specimen_collection_site is incorrectly attached in the caTissue class
    #   model to AbstractSpecimenCollectionGroup rather than SpecimenCollectionGroup. CollectionProtocolEvent
    #   is a subclass of AbstractSpecimenCollectionGroup but does not have a collection site. Therfore, the
    #   specimen_collection_site is ignored in the caRuby AbstractSpecimenCollectionGroup class declaration
    #   and declared as an aliased, mandatory, fetched attribute for the SpecimenCollectionGroup subclass only.
    add_mandatory_attributes(:specimen_collection_site, :clinical_diagnosis, :collection_status)
    
    qualify_attribute(:specimen_collection_site, :fetched)

    set_secondary_key_attributes(:name)

    set_alternate_key_attributes(:surgical_pathology_number, :specimen_collection_site)

    # @quirk caTissue An auto-generated or created SCG auto-generates a ConsentTierStatus for each
    #   ConsentTierResponse defined in the SCG owner CPR.
    #
    # @quirk caTissue SCG consent_tier_statuses is cascaded but not fetched.
    add_dependent_attribute(:consent_tier_statuses, :autogenerated, :unfetched)

    # @quirk caTissue SCG event parameters are disjoint, since they are owned by either a SCG
    #   or a Specimen, but not both. An auto-generated SCG also auto-generates the Collection 
    #   and Received SEPs. A SCG SEP is only created as a dependent when the SCG is created.
    #   A SCG SEP cannot be created for an existing SCG. By contrast, a Specimen SEP can only
    #   be created, not updated.
    #
    # @quirk caTissue Update of an auto-generated SpecimenCollectionGroup ignores the referenced
    #   collection and received event parameters and instead creates new parameters. This occurs
    #   only on the first update, and an SEP cannot be added to an existing, updated SCG.
    #   Work-around is to update the SCG template without the parameters, merge the auto-generated
    #   SEP into the referenced SEP, then save the SEPs separately.
    #
    # @quirk caTissue although SpecimenCollectionGroup auto-generated update ignores referenced
    #   collection and received event parameters, these parameters are mandatory for the update.
    add_dependent_attribute(:specimen_event_parameters, :disjoint, :fetch_saved)

    # SCG Specimens are auto-generated from SpecimenRequirement templates when the SCG is created.
    # The Specimens are not cascaded.
    #
    # @quirk caTissue SCG specimens query result does not set the Specimen children and parent, even
    #   though they are guaranteed to be in the SCG specimens result set. The children and parent must be
    #   fetched separately, resulting in redundant copies of the same Specimen and additional fetches.
    #   caRuby partially rectifies this lapse by reconciling the SCG specimens parent-child relationships
    #   within the SCG scope.
    add_dependent_attribute(:specimens, :logical, :autogenerated)

    # CPE is fetched but not cascaded.
    qualify_attribute(:collection_protocol_event, :fetched)

    # @quirk caTissue caTissue requires that a SpecimenCollectionGroup update object references a
    #   CollectionProtocolRegistration with a Participant reference. This is a caTissue bug, since the
    #   CPR identifier should be sufficient for a SCG update, but caTissue bizlogic requires an extraneous
    #   CPR -> Participant reference. The work-around is too mark the attribute with a special
    #   +:include_in_save_template+ flag.
    qualify_attribute(:collection_protocol_registration, :include_in_save_template)

    # @quirk caTissue Bug #65: Although SCG name uniquely identifies a SCG, the SCG name is auto-generated on create
    #   and cannnot be set by the client. Therefore, name is marked as update_only.
    qualify_attribute(:name, :autogenerated, :update_only)

    # The SCG pathology annotation.
    add_annotation('Pathology', :package => 'pathology_scg', :service => 'pathologySCG', :proxy_name => 'SCGRecordEntry')

    # @quirk caTissue Bug #64: Initialize the SCG consent_tier_statuses to an empty set.
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
    # {CaTissue::Collectible#merge_attributes} as follows:
    # * Adds the transitive closure of each non-derived Specimen in the source.
    #
    # @param (see CaTissue::Collectible#merge_attributes)
    # @option (see CaTissue::Collectible#merge_attributes)
    def merge_attributes(other, attributes=nil, matches=nil, &filter)
      if Hash === other then
        # take the transitive closure of the specimens
        spcs = other.delete(:specimens)
        if spcs then
          spcs = [spcs] if CaTissue::Specimen === spcs
          # take the transitive closure of the root specimens in the hierarchy
          other[:specimens] = spcs.select { |spc| spc.parent.nil? }.transitive_closure(:children)
        end
      end
      # delegate to Collectible
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

    # Overrides +Jinx::Resource.direct_dependents+ in the case of the _specimens_ attribute to select
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
      pas = super
      if registration and not registration.consent_tier_responses.empty? then
        pas + CONSENT_TIER_STATUS_ATTRS
      else
        pas
      end
    end

    # Relaxes the +CaRuby::Persistable.saved_attributes_to_fetch+ condition for a SCG as follows:
    # * If the SCG status was updated from +Pending+ to +Collected+, then fetch the saved SCG event parameters.
    # 
    # @param (see CaRuby::Persistable#saved_attributes_to_fetch)
    # @return (see CaRuby::Persistable#saved_attributes_to_fetch)
    def saved_attributes_to_fetch(operation)
      operation == :update && status_changed_to_complete? ? EVENT_PARAM_ATTRS : super
    end
    
    # Relaxes the +CaRuby::Persistable.saved_attributes_to_fetch+ condition for a SCG as follows:
    # * If the SCG status was updated from +Pending+ to +Collected+, then fetch the saved SCG event parameters.
    # 
    # @param (see CaRuby::Persistable#saved_attributes_to_fetch)
    # @return (see CaRuby::Persistable#saved_attributes_to_fetch)
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
        
    # @see #autogenerated?
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
    # @raise [Jinx::ValidationError] if the default ReceivedEventParameters could not be created because
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
      ev = pcl.sorted_events.first || return
      logger.debug { "Default #{qp} collection event is the registration protocol #{pcl.qp} first event #{ev.qp}." }
      ev
    end

    def create_default_received_event_parameters
      rcv = default_receiver
      if rcv.nil? then
        raise Jinx::ValidationError.new("SCG with status Complete default CollectionEventParameters could not be created since there is no #{self} collection protocol coordinator")
      end
      # make the REP
      ev = CaTissue::SpecimenEventParameters.create_parameters(:received, self, :user => rcv)
      ev.add_defaults_recursive
      logger.debug { "Made default #{qp} received event parameter #{ev.qp}." }
      ev
    end
                                                   
    # Returns the collection protocol coordinator. Fetches the CP if necessary and possible.
    # Adds defaults to the CP if necessary, which sets a default coordinator if possible.
    #
    # @return [CaTissue::User] the default receiver
    def default_receiver
      cep = collection_event_parameters
      cltr = cep.user if cep
      return cltr if cltr
      cp = collection_protocol || return
      rcv = cp.coordinators.first
      return rcv if rcv or cp.fetched?
      # Try to fetch the CP coordinator 
      return cp.coordinators.first if cp.find
      # CP does not exist; add the CP defaults and retry
      cp.add_defaults
      cp.coordinators.first
    end

    def create_default_collection_event_parameters
      rep = received_event_parameters || return
      # make the CEP from the REP
      ev = CaTissue::SpecimenEventParameters.create_parameters(:collection, self, :user => rep.user, :timestamp => rep.timestamp)
      ev.add_defaults_recursive
      logger.debug { "Made default #{qp} collected event parameter #{ev.qp}." }
      ev
    end

    # @raise [Jinx::ValidationError] if there is a registration consent tier response without a corresponding SCG consent tier status
    def validate_consent
      return unless registration
      # the default consent statuses
      ctses = consent_tier_statuses.map { |cts| cts.consent_tier }
      registration.consent_tier_responses.each do |ctr|
        ct = ctr.consent_tier
        unless ctses.include?(ct) then
          raise Jinx::ValidationError.new("#{self} is missing a ConsentTierStatus for consent statement #{ct.statement}")
        end
      end
    end

    # @raise [Jinx::ValidationError] if the SCG has neither an identifier nor Received and Collection event parameters
    def validate_event_parameters
      if identifier.nil? and event_parameters.empty? then
        raise Jinx::ValidationError.new("#{self} create is missing the required Received and Collection event parameters")
      end
    end
  end
end