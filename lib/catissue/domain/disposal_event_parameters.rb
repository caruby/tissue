module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.DisposalEventParameters

  class DisposalEventParameters < CaTissue::SpecimenEventParameters
    add_attribute_defaults(:activity_status => 'Closed')

    # @quirk caTissue DisposalEventParameters activity status is transient.
    qualify_attribute(:activity_status, :unfetched)
  end
end