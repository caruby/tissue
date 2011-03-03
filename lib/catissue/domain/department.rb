

module CaTissue
  # import the Java class
  java_import Java::edu.wustl.catissuecore.domain.Department

  # The Department domain class.
  class Department
    include Resource

    set_secondary_key_attributes(:name)
  end
end