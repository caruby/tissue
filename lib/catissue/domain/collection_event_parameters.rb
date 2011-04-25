require 'catissue/util/collectible_event_parameters'
require 'caruby/util/validation'

module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.CollectionEventParameters

  class CollectionEventParameters < CaTissue::SpecimenEventParameters
    include CollectibleEventParameters
    
    # @param [CaTissue::Specimen] the specimen to set
    # @raise [ValidationError] if the specimen already has a ReceivedEventParameters
    def specimen=(specimen)
      cep = specimen.collection_event_parameters if specimen
      if cep and cep != self then
        raise ValidationError.new("Cannot add #{qp} to #{specimen}, since it already contains #{cep}")
      end
      setSpecimen(specimen)
      specimen.specimen_event_parameters << self if specimen
      specimen
    end
    
    # @param [CaTissue::Specimen] the specimen to set
    # @raise [ValidationError] if the specimen already has a ReceivedEventParameters
    def specimen_collection_group=(scg)
      cep = scg.collection_event_parameters if scg
      if cep and cep != self then
        raise ValidationError.new("Cannot add #{qp} to #{scg}, since it alreadycontains #{cep}")
      end
      setSpecimenCollectionGroup(scg)
      scg.specimen_event_parameters << self if scg
      scg
    end
    
    add_attribute_defaults(:collection_procedure => 'Not Specified', :container => 'Not Specified')
    
    # An auto-generated CEP must fetch the user.
    qualify_attribute(:user, :saved_fetch)

  end
end