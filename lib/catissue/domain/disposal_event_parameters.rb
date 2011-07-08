module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.DisposalEventParameters

  # @quirk caTissue DisposalEventParameters activity status is transient.
  class DisposalEventParameters < CaTissue::SpecimenEventParameters
    add_attribute_defaults(:activity_status => 'Closed')

    qualify_attribute(:activity_status, :unfetched)
  end
end