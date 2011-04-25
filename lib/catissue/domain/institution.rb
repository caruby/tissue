

module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.Institution

  # The Institution domain class.
  class Institution
    set_secondary_key_attributes(:name)
  end
end