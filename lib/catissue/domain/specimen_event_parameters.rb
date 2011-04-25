require 'caruby/util/validation'
require 'caruby/util/inflector'
require 'catissue/util/collectible'

module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.SpecimenEventParameters

  class SpecimenEventParameters
    # date is a synonym for the more accurately titled timestamp attribute.
    add_attribute_aliases(:date => :timestamp)

    add_mandatory_attributes(:timestamp, :user)

    # specimen is abstract but unfetched.
    qualify_attribute(:specimen, :unfetched)

    private

    def self.allocate
      raise NotImplementedError.new("SpecimenEventParameters is abstract; use the create method to make a new instance")
    end

    public

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
    def self.create_parameters(type, scg_or_specimen, params=Hash::EMPTY_HASH)
      # make the class name by joining the camel-cased type prefix to the subclass suffix.
      # classify converts a lower_case, underscore type to a valid class name, e.g. :check_in_check_out
      # becomes CheckInCheckOut.
      class_name = type.to_s.classify + SUBCLASS_SUFFIX
      begin
        klass = CaTissue.const_get(class_name.to_sym)
      rescue
        raise ArgumentError.new("Unsupported event parameters type: #{type}; #{class_name} must be a subtype of #{self}")
      end
      event_params = klass.new(params)
      case scg_or_specimen
        when SpecimenCollectionGroup then event_params.specimen_collection_group = scg_or_specimen
        when Specimen then event_params.specimen = scg_or_specimen
        when nil then raise ArgumentError.new("Missing SpecimenEventParameters scg_or_specimen factory argument")
        else
          raise ArgumentError.new("Unsupported SpecimenEventParameters factory argument - expected SpecimenCollectionGroup or Specimen, found #{scg_or_specimen.class}")
      end
      event_params
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
    
    def saved_fetch_attributes(operation)
      attrs = super
      # TODO - KLUDGE!!!! simple_test migration test fails to set user ---- FIX!!!!
      if identifier and not attrs.include?(:user) then
        attrs + [:user]
      else
        attrs
      end
    end
    
    private

    SUBCLASS_SUFFIX = 'EventParameters'

    def validate_local
      super
      if subject.nil? then
        raise ValidationError.new("Both specimen_collection_group and specimen are missing in SpecimenEventParameters #{self}")
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

    def default_user
      scg = specimen_collection_group || (specimen.specimen_collection_group if specimen)
      scg.receiver if scg
    end
  end
end