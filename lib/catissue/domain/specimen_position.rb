module CaTissue
  # import the Java class
  java_import('edu.wustl.catissuecore.domain.SpecimenPosition')

  class SpecimenPosition
    include Resource

    add_mandatory_attributes(:storage_container)

    add_attribute_aliases(:holder => :storage_container, :container => :storage_container, :occupant => :specimen)

    # Each SpecimenPosition has a specimen and there is only one position per specimen.
    set_secondary_key_attributes(:specimen)

    set_attribute_inverse(:storage_container, :specimen_positions)

    set_attribute_inverse(:specimen, :specimen_position)
    
    qualify_attribute(:storage_container, :fetched)

    # Returns a TransferEventParameters which serves as a proxy for saving this SpecimenPosition.
    #
    # caTissue alert - caTissue does not allow saving a SpecimenPosition directly in the database.
    # Creating a TransferEventParameters sets the SpecimenPosition as a side-effect. Therefore,
    # SpecimenPosition save is accomplished by creating a proxy TransferEventParameters instead.
    def saver_proxy
      xfr = CaTissue::TransferEventParameters.new(:specimen => specimen, :to => location)
      if snapshot and changed? then
        xfr.from_storage_container = snapshot[:storage_container]
        xfr.from_position_dimension_one = snapshot[:position_dimension_one]
        xfr.from_position_dimension_two = snapshot[:position_dimension_two]
      end
      xfr
    end
  end
end