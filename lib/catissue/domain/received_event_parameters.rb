require 'catissue/helpers/collectible_event_parameters'

module CaTissue
  class ReceivedEventParameters
    include CollectibleEventParameters

    add_attribute_aliases(:receiver => :user)

    add_attribute_defaults(:received_quality => 'Not Specified')

    add_mandatory_attributes(:received_quality)
    
    # An auto-generated REP must fetch the user.
    qualify_attribute(:user, :fetch_saved)

    private

    # Returns the first SCG CP coordinator, if any.
    def default_user
      scg = specimen_collection_group || (specimen.specimen_collection_group if specimen) || return
      cp = scg.collection_protocol || return
      cp.coordinators.first || (cp.sites.first.coordinator if cp.sites.size === 1)
    end
  end
end