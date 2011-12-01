module CaTissue
  class Specimen
    class Pathology
      # @quirk caTissue The 1.1 class Details is renamed to SpecimenDetails in 1.2.
      #   Alias the SpecimenDetails Ruby class to Details for backward compatibility.
      class SpecimenDetails
        Pathology.const_set(:Details, self)
        logger.debug { "Aliased the Specimen pathology annotation class SpecimenDetails to Details." }
      end
    end
  end
end
