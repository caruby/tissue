module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.FrozenEventParameters

  class FrozenEventParameters < CaTissue::SpecimenEventParameters
    add_attribute_aliases(:freeze_method => :frozen_event_parameters_method)
  end
end