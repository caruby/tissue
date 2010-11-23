require 'catissue/domain/scg_event_parameters'

module CaTissue
  # import the Java class
  java_import('edu.wustl.catissuecore.domain.ReceivedEventParameters')

  class ReceivedEventParameters
    include Resource, SCGEventParameters

    add_attribute_aliases(:receiver => :user)

    add_attribute_defaults(:received_quality => 'Not Specified')

    add_mandatory_attributes(:received_quality)

    private

    # Returns the first SCG CP coordinator, if any.
    def default_user
      scg = specimen_collection_group || (specimen.specimen_collection_group if specimen) || return
      cp = scg.collection_protocol || return
      cp.coordinators.first || (cp.sites.first.coordinator if cp.sites.size === 1)
    end
  end
end