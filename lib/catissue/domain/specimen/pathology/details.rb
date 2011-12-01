module CaTissue
  class Specimen
    class Pathology
      # @quirk caTissue The 1.1 class Details is renamed to SpecimenDetails in 1.2.
      #   Alias the Details Ruby class to SpecimenDetails for forward compatibility.
      class Details
        Pathology.const_set(:SpecimenDetails, self)
        logger.debug { "Aliased the Specimen pathology annotation class Details to SpecimenDetails." }
      end
    end
  end
end
