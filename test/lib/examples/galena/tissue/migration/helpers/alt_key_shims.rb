module CaTissue
  shims Participant
  
  class Participant
    set_secondary_key_attributes(:first_name, :last_name)
  end
end