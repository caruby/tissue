module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.ExternalIdentifier

  # The ExternalIdentifier domain class.
  class ExternalIdentifier
    add_mandatory_attributes(:value)

    set_secondary_key_attributes(:specimen, :name)
  end
end