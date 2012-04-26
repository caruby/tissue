require 'jinx/helpers/validation'
require 'jinx/helpers/inflector'
require 'catissue/helpers/collectible'

module CaTissue
  class SpecimenEventParameters
    # date is a synonym for the more accurately titled timestamp attribute.
    add_attribute_aliases(:date => :timestamp)

    add_mandatory_attributes(:timestamp, :user)

    # specimen is abstract but unfetched.
    qualify_attribute(:specimen, :unfetched)

    # Creates a SpecimenEventParameters of the specified subclass type. The type is a
    # SpecimenEventParameters subclass name without the +EventParameters+ suffix, e.g.
    # +Collection+. Lower-case, underscore symbols are supported and preferred, e.g. the
    # :collection type creates a CollectionEventParameters.
    #
    # The required scg_or_specimen argument is either a SpecimenCollectionGroup or
    # a Specimen.
    #
    # The optional params argument are attribute => value associations, e.g.
    #   SpecimenEventParameters.create_parameters(:collection, scg, :user => collector, :timestamp => DateTime.now)
    #
    # @param [String, Symbol] type the event type
    # @param [SpecimenCollectionGroup, Specimen] scg_or_specimen the event owner
    # @param [{Symbol => Object}, nil] params the attribute => value associations
    def self.create_parameters(type, scg_or_specimen, params=Hash::EMPTY_HASH)
      # make the class name by joining the camel-cased type prefix to the subclass suffix.
      # classify converts a lower_case, underscore type to a valid class name,
      # e.g. +:check_in_check_out+ becomes +CheckInCheckOut+.
      class_name = type.to_s.classify + SUBCLASS_SUFFIX
      begin
        klass = CaTissue.const_get(class_name.to_sym)
      rescue
        raise ArgumentError.new("Unsupported event parameters type: #{type}; #{class_name} must be a subtype of #{self}")
      end
      ep = klass.new(params)
      case scg_or_specimen
        when CaTissue::SpecimenCollectionGroup then ep.specimen_collection_group = scg_or_specimen
        when CaTissue::Specimen then ep.specimen = scg_or_specimen
        when nil then raise ArgumentError.new("Missing SpecimenEventParameters SCG or Specimen owner argument")
        else
          raise ArgumentError.new("Unsupported SpecimenEventParameters factory argument - expected SpecimenCollectionGroup or Specimen, found #{scg_or_specimen.class}")
      end
      ep
    end

    # @return [CaTissue::Collectible] specimen or SCG to which this event is attached
    def subject
      specimen.nil? ? specimen_collection_group : specimen
    end

    # @param [CaTissue::Collectible] specimen or SCG to attach with this event
    def subject=(scg_or_specimen)
      spc_subject = scg_or_specimen if Specimen === scg_or_specimen
      scg_subject = scg_or_specimen if SpecimenCollectionGroup === scg_or_specimen
      specimen = spc_subject
      specimen_collection_group = scg_subject
      scg_or_specimen
    end

    # @return [CaTissue::CollectionProtocol] the SCG protocol
    def collection_protocol
      specimen_collection_group.collection_protocol if specimen_collection_group
    end
    
    private

    # The class name suffix for all event parameter classes.
    SUBCLASS_SUFFIX = 'EventParameters'

    def self.allocate
      raise NotImplementedError.new("SpecimenEventParameters is abstract; use the create method to make a new instance")
    end

    # @raise [Jinx::ValidationError] if the subject is missing or there is both a SCG and a Specimen owner
    def validate_local
      super
      if subject.nil? then
        raise Jinx::ValidationError.new("Both specimen_collection_group and specimen are missing in SpecimenEventParameters #{self}")
      end
    end

    # Sets each missing value to a default as follows:
    # * default user is the SCG receiver
    # * default timestamp is now
    def add_defaults_local
      super
      self.timestamp ||= Java.now
      self.user ||= default_user
    end

    # @return [CaTissue::User] the specimen or SCG receiver
    def default_user
      rcv = database.lazy_loader.enable { specimen.receiver } if specimen
      return rcv if rcv
      scg = specimen_collection_group || (specimen.specimen_collection_group if specimen)
      database.lazy_loader.enable { scg.receiver } if scg
    end
  end
end