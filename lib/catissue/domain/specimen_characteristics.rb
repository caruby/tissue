

module CaTissue
  class SpecimenCharacteristics
    add_attribute_defaults(:tissue_side => 'Not Specified', :tissue_site => 'Not Specified')

    add_mandatory_attributes(:tissue_site, :tissue_side)

    # The tissue_side constants.
    class TissueSide
      LEFT = 'Left'
      RIGHT = 'Right'
    end
  end
end