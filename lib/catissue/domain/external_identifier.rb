

module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.ExternalIdentifier

  # The ExternalIdentifier domain class.
  class ExternalIdentifier
    # Sets this ExternalIdentifier value to the given value.
    # A Numeric value is converted to a String.
    def value=(value)
      value = value.to_s if value
      setValue(value)
    end

    add_mandatory_attributes(:value)

    set_secondary_key_attributes(:specimen, :name)
  end
end