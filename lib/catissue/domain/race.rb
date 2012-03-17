module CaTissue
  class Race
    add_attribute_aliases(:name => :race_name)
    
    add_attribute_defaults(:race_name => 'Unknown')
  end
end