module CaTissue
  # The ExternalIdentifier domain class.
  class ExternalIdentifier
    add_mandatory_attributes(:value)

    set_secondary_key_attributes(:specimen, :name)
  end
end