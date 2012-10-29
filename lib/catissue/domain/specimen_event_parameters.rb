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

    # @return [CaTissue::CollectionProtocol] the SCG protocol
    def collection_protocol
      specimen_collection_group.collection_protocol if specimen_collection_group
    end
    
    private

    def self.allocate
      raise NotImplementedError.new("SpecimenEventParameters is abstract; use the create method to make a new instance")
    end

    # @raise [Jinx::ValidationError] if the owner is missing or there is both a SCG and a Specimen owner
    def validate_local
      super
      if owner.nil? then
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