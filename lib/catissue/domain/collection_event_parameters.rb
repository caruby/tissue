require 'catissue/helpers/collectible_event_parameters'

module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.CollectionEventParameters

  class CollectionEventParameters
    include CollectibleEventParameters
    
    add_attribute_defaults(:collection_procedure => 'Not Specified', :container => 'Not Specified')
    
    # An auto-generated CEP must fetch the user.
    qualify_attribute(:user, :fetch_saved)
  end
end