module CaTissue
  # import the Java class
  java_import Java::edu.wustl.catissuecore.domain.Race

  class Race
    include Resource

    add_attribute_defaults(:race_name => 'Unknown')

  end
end