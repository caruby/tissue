module CaTissue
  java_import Java::edu.wustl.catissuecore.domain.Address

  class Address
    include Resource

    # Sets this Address's zip_code to value. The value argument can be nil, a String or an Integer.
    def zip_code=(value)
      value = value.to_s if Integer === value
      setZipCode(value)
    end
  end
end