module CaTissue
  # import the Java class
  java_import('edu.wustl.catissuecore.domain.ConsentTierResponse')

  class ConsentTierResponse
    include Resource

    add_mandatory_attributes(:consent_tier, :response)

    add_attribute_defaults(:response => 'Not Specified')

  end
end