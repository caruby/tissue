require 'catissue/util/collectible_event_parameters'
require 'caruby/util/validation'

module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.ReceivedEventParameters

  class ReceivedEventParameters < CaTissue::SpecimenEventParameters
    include CollectibleEventParameters
    
    # @param [CaTissue::Specimen] the specimen to set
    # @raise [ValidationError] if the specimen already has a ReceivedEventParameters
    def specimen=(specimen)
      rep = specimen.received_event_parameters if specimen
      if rep and rep != self then
        raise ValidationError.new("Cannot add #{qp} to #{specimen}, since it already contains #{rep}")
      end
      setSpecimen(specimen)
      specimen.specimen_event_parameters << self if specimen
      specimen
    end
    
    # @param [CaTissue::Specimen] the specimen to set
    # @raise [ValidationError] if the specimen already has a ReceivedEventParameters
    def specimen_collection_group=(scg)
      rep = scg.received_event_parameters if scg
      if rep and rep != self then
        raise ValidationError.new("Cannot add #{qp} to #{scg}, since it already contains #{rep}")
      end
      setSpecimenCollectionGroup(scg)
      scg.specimen_event_parameters << self if scg
      scg
    end

    add_attribute_aliases(:receiver => :user)

    add_attribute_defaults(:received_quality => 'Not Specified')

    add_mandatory_attributes(:received_quality)
    
    # An auto-generated REP must fetch the user.
    qualify_attribute(:user, :saved_fetch)

    private

    # Returns the first SCG CP coordinator, if any.
    def default_user
      scg = specimen_collection_group || (specimen.specimen_collection_group if specimen) || return
      cp = scg.collection_protocol || return
      cp.coordinators.first || (cp.sites.first.coordinator if cp.sites.size === 1)
    end
  end
end