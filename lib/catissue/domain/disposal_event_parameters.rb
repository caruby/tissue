module CaTissue
  class DisposalEventParameters
    add_attribute_defaults(:activity_status => 'Closed')

    # @quirk caTissue DisposalEventParameters activity status is transient.
    #
    # @quirk caTissue DisposalEventParameters activity status is not set in a create.
    #   The work-around is to perform a subsequent update on the created event.
    qualify_attribute(:activity_status, :unfetched, :update_only)
  end
end