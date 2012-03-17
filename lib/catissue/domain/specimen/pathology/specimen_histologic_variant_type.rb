module CaTissue
  class Specimen
    module Pathology
      # @quirk caTissue The 1.1.2 class HistologicVariantType is renamed to SpecimenHistologicVariantType in 1.2.
      #   Alias the SpecimenHistologicVariantType Ruby class to HistologicVariantType for backward compatibility.
      class SpecimenHistologicVariantType
        Pathology.const_set(:HistologicVariantType, self)
        logger.debug { "Aliased the Specimen pathology annotation class SpecimenHistologicVariantType to HistologicVariantType." }
      end
    end
  end
end
