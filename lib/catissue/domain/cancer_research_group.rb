module CaTissue
  # import the Java class
  java_import Java::edu.wustl.catissuecore.domain.CancerResearchGroup

  # The CancerResearchGroup domain class.
  class CancerResearchGroup
    include Resource

    set_secondary_key_attributes(:name)
  end
end