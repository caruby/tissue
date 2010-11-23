module CaTissue
  # import the Java class
  java_import('edu.wustl.catissuecore.domain.DisposalEventParameters')

  class DisposalEventParameters
    include Resource

    add_attribute_defaults(:activity_status => 'Closed')

    # caTissue alert - DisposalEventParameters activity status is transient.
    qualify_attribute(:activity_status, :unfetched)
  end
end