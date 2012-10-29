module CaTissue
  # @quirk caTissue The caTissue Race is denormalized to include both the race name
  #   and the race-participant association, i.e. the race name controlled value is
  #   replicated in each association rather than in a Race enumeration class.
  class Race
    add_attribute_aliases(:name => :race_name)
    
    add_attribute_defaults(:race_name => 'Unknown')
  end
end