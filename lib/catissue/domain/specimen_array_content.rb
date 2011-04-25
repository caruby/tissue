require 'catissue/util/position'

module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.SpecimenArrayContent

  # caTissue alert - #{CaTissue::SpecimenArrayContent} should be derived from
  # {CaTissue::AbstractPosition} but isn't (cf. {CaTissue::ContainerType}).
  # Partially rectify this by including the {Position} mix-in in common with
  # {CaTissue::AbstractPosition}.
  class SpecimenArrayContent
    include Position

    add_attribute_aliases(:holder => :specimen_array, :occupant => :specimen)

    # Each SpecimenArrayContent has a specimen and there is only one such slot per specimen.
    set_secondary_key_attributes(:specimen)
  end
end