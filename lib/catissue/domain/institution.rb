

module CaTissue
  # import the Java class
  java_import Java::edu.wustl.catissuecore.domain.Institution

  # The Institution domain class.
  class Institution
    include Resource

    set_secondary_key_attributes(:name)
  end
end