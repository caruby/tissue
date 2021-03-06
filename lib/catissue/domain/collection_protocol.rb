require 'date'
require 'catissue/helpers/hash_code'

module CaTissue
  # The CollectionProtocol domain class.
  #
  # @quirk caTissue Augment the standard metadata savable reference attributes to work around caTissue Bug #150:
  #   Create CollectionProtocol in API ignores +startDate+.
  #
  # @quirk caTissue The CP +collection_protocol_registrations+ cannot be inferred as the CPR +collection_protocol+
  #   inverse since the +collectionProtocolRegistrations+ Java reader method is untyped.
  #   The inverse is manually established in {CollectionProtocolRegistration}.
  class CollectionProtocol
    include HashCode
    
    # @quirk caTissue Bug #64: Some domain collection properties not initialized.
    #   Initialize consent_tiers if necessary. 
    #
    # @return [Java::JavaUtil::Set] the tiers
    def consent_tiers
      getConsentTierCollection or (self.consent_tiers = Java::JavaUtil::LinkedHashSet.new)
    end

    add_attribute_aliases(:events => :collection_protocol_events, :registrations => :collection_protocol_registrations)
    
    # @quirk caTissue The CP +collection_protocol_registrations+ is unnecessary and expensive to maintain
    #   inverse integrity with lazy-loading. The CP registrations is more properly obtained by a query.
    #   However, it is useful to retain the property as a house-keeping convenience. Therefore, the
    #   work-around is to mark the property as transient to forego lazy loading.
    qualify_attribute(:collection_protocol_registrations, :transient)

    add_attribute_defaults(:consents_waived => false, :aliquot_in_same_container => false)

    add_mandatory_attributes(:aliquot_in_same_container, :collection_protocol_events, :consents_waived, :enrollment)

    add_dependent_attribute(:collection_protocol_events)

    add_dependent_attribute(:consent_tiers)

    # @quirk caTissue Augment the standard metadata savable reference attributes to work around caTissue Bug #150:
    #   Create CollectionProtocol in API ignores startDate.
    qualify_attribute(:start_date, :update_only)

    set_attribute_type(:coordinators, CaTissue::User)

    qualify_attribute(:coordinators, :fetched)

    # @quirk caTissue Bug #64 - consent tiers collection property is not initialized to an empty set in the Java constructor.
    #   Initialize it to a +LinkedHashSet+ in caRuby.
    def initialize
      super
      # @quirk JRuby consent_tiers property method is not accessible until respond_to? is called.
      respond_to?(:consent_tiers)
      self.consent_tiers ||= Java::JavaUtil::LinkedHashSet.new
    end

    # Returns a new CollectionProtocolRegistration for the specified participant in this CollectionProtocol with
    # optional +protocol_participant_identifier+ ppi.
    def register(participant, ppi=nil)
      CollectionProtocolRegistration.new(:participant => participant, :protocol => self, :protocol_participant_identifier => ppi)
    end

    # Returns this protocol's events sorted by study calendar event point.
    def sorted_events
      events.sort_by { |ev| ev.event_point || CollectionProtocolEvent::DEFAULT_EVENT_POINT }
    end

    # Adds specimens to this protocol. The argumentes includes the
    # specimens to add followed by a Hash with parameters and options.
    # If the SCG registration parameter is not set, then a default registration
    # is created which registers the given participant to this protocol.
    #
    # @example
    #   protocol.add_specimens(tumor, normal, :participant => pnt, :collector => srg) 
    #   #=> a new SCG for the given participant with a matched pair of samples
    #   #=> collected by the given surgeon.
    #
    # @param [(<Specimen>, {Symbol => Object})] args the specimens to add followed
    #   by the parameters and options hash
    # @option args [CaTissue::Participant] :participant the person from whom the
    #   specimen is collected
    # @return [CaTissue::SpecimenCollectionGroup] the new SCG
    # @raise [ArgumentError] if the options do not include either a participant or a registration
    def add_specimens(*args)
      hash = args.pop
      spcs = args
      # validate arguments
      unless Hash === hash then
        raise ArgumentError.new("Collection parameters are missing when adding specimens to protocol #{self}")
      end
      # Make the default registration, if necessary.
      unless hash.has_key?(:registration) || hash.has_key?(:collection_protocol_registration) then
        # the participant
        pnt = hash.delete(:participant)
        unless pnt then
          raise ArgumentError.new("Registration or participant missing from collection parameters: #{hash.qp}")
        end
        hash[:registration] = registration(pnt) || make_cpr(pnt)
      end
      # the new SCG
      scg = SpecimenCollectionGroup.new(hash)
      # set each Specimen SCG
      spcs.each { |spc| spc.specimen_collection_group = scg }
      scg
    end
    
    # Returns the default protocol site, determined as follows:
    # * If there is exactly one coordinator with one site, then the coordinator's site is the default.
    # * Otherwise, if there is exactly one authorized site for this protocol, then that is the default site.
    # * Otherwise, if there is exactly two authorized sites for this protocol, then the site other than the
    #   {CaTissue::Site.default_site} is returned.
    # * Otherwise, this method returns nil.
    #
    # @return [CaTissue::Site, nil] the default site
    def default_site
      coord = coordinators.first if coordinators.size == 1
      site = coord.sites.first if coord and coord.sites.size == 1
      return site if site
      # If this CP's identifier was set by the client but the CP was not fetched, then do so now
      # in order to enable lazy-loading the sites.
      find if sites.empty? and identifier and not fetched?
      case sites.size
      when 1 then sites.first
      when 2 then sites.select { |site| site.name != CaTissue::Site.default_site.name }
      end
    end

    private
    
    # This method only checks the transient registrations. Database registrations are not
    # fetched.
    #
    # @param [CaTissue::Participant] participant the participant to check
    # @return [CaTissue::CollectionProtocolRegistration, nil] the registration for the
    #   given participant in this protocol
    def registration(participant)
      registrations.detect { |registration| registration.participant == participant }
    end
    
    # Sets the defaults as follows:
    # * The start date is set to now.
    # * The title is set to the short title.
    # * If there is no CP coordinator and there is exactly one site with a coordinator, then the
    #   default CP coordinator is the site coordinator.
    # * If there is no CP site and there is exactly one coordinator site, then the default CP site
    #   is the coordinator site.
    def add_defaults_local
      super
      self.start_date ||= Java::JavaUtil::Date.new
      if sites.empty? then add_default_site end
      if coordinators.empty? and sites.size == 1 then
        coord = sites.first.coordinator
        coordinators << coord if coord
      end
      make_default_collection_event unless events.detect { |evt| CollectionProtocolEvent === evt }
    end
    
    def add_default_site
      if coordinators.size == 1 then
        site = coordinators.first.sites.first
      end
      site ||= CaTissue::Site.default_site
      sites << site
    end

    def make_default_collection_event
      # make this protocol's CPE
      cpe = CollectionProtocolEvent.new(:protocol => self)
      # make a tissue requirement
      CaTissue::TissueSpecimenRequirement.new(
        :collection_event => cpe,
        :specimen_characteristics => CaTissue::SpecimenCharacteristics.new)
    end
    
    def make_cpr(participant)
      CollectionProtocolRegistration.new(:participant => participant, :protocol => self)
    end
  end
end