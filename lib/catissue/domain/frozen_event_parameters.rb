module CaTissue
  # import the Java class
  java_import Java::edu.wustl.catissuecore.domain.FrozenEventParameters

  class FrozenEventParameters
    include Resource

    add_attribute_aliases(:freeze_method => :frozen_event_parameters_method)
  end
end