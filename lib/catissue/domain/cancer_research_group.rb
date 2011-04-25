module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.CancerResearchGroup

  # The CancerResearchGroup domain class.
  class CancerResearchGroup
    set_secondary_key_attributes(:name)
  end
end