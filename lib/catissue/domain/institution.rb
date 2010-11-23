

module CaTissue
  # import the Java class
  java_import('edu.wustl.catissuecore.domain.Institution')

  # The Institution domain class.
  class Institution
    include Resource

    set_secondary_key_attributes(:name)
  end
end