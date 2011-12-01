module CaTissue
  class Specimen
    class Pathology
      # @quirk caTissue The 1.1.2 class HistologicVariantType is renamed to SpecimenHistologicVariantType in 1.2.
      #   Alias the HistologicVariantType Ruby class to SpecimenHistologicVariantType for forward compatibility.
      class HistologicVariantType
        Pathology.const_set(:SpecimenHistologicVariantType, self)
        logger.debug { "Aliased the caTissue 1.1 Specimen pathology annotation class HistologicVariantType class to the renamed 1.2 SpecimenHistologicVariantType." }
      end
    end
  end
end
