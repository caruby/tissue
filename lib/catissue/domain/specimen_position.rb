module CaTissue
  class SpecimenPosition
    add_mandatory_attributes(:storage_container)

    add_attribute_aliases(:holder => :storage_container, :container => :storage_container, :from => :storage_container,
      :occupant => :specimen, :to => :specimen)

    # Each SpecimenPosition has a specimen and there is only one position per specimen.
    set_secondary_key_attributes(:specimen)

    set_attribute_inverse(:storage_container, :specimen_positions)

    set_attribute_inverse(:specimen, :specimen_position)
    
    qualify_attribute(:storage_container, :fetched)

    # Returns a TransferEventParameters which serves as a proxy for saving this SpecimenPosition.
    #
    # @quirk caTissue caTissue does not allow saving a SpecimenPosition directly in the database.
    #   Creating a TransferEventParameters sets the SpecimenPosition as a side-effect. Therefore,
    #   SpecimenPosition save is accomplished by creating a proxy TransferEventParameters instead.
    def saver_proxy
      # Look for a transfer event that matches the position.
      xfr = specimen.all_event_parameters.detect do |sep|
        CaTissue::TransferEventParameters === sep and sep.to == location
      end
      # Create a new transfer event, if necessary.
      xfr ||= CaTissue::TransferEventParameters.new(:specimen => specimen, :to => location)
      # If this position changed, then copy the original position to the transfer event from attributes.
      if snapshot and changed? then
        xfr.from_storage_container = snapshot[:storage_container]
        xfr.from_position_dimension_one = snapshot[:position_dimension_one]
        xfr.from_position_dimension_two = snapshot[:position_dimension_two]
      end
      xfr
    end
  end
end