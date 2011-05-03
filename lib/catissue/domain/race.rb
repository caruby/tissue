module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.Race

  class Race
    add_attribute_aliases(:name => :race_name)
    
    add_attribute_defaults(:race_name => 'Unknown')
  end
end