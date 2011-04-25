module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.ConsentTierResponse

  class ConsentTierResponse
    add_mandatory_attributes(:consent_tier, :response)

    add_attribute_defaults(:response => 'Not Specified')
    
    qualify_attribute(:consent_tier, :fetched)

  end
end