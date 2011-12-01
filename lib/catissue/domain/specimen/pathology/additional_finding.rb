module CaTissue
  class Specimen
    # @quirk caTissue The 1.1.2 class AdditionalFinding is renamed to SpecimenAdditionalFinding in 1.2.
    # Alias the AdditionalFinding Ruby class constant to SpecimenAdditionalFinding for forward compatibility.
    class Pathology
      class AdditionalFinding
        Pathology.const_set(:SpecimenAdditionalFinding, self)
        logger.debug { "Aliased the caTissue 1.1.2 Specimen pathology annotation class AdditionalFinding class to the renamed 1.2 SpecimenAdditionalFinding." }
      end
    end
  end
end
