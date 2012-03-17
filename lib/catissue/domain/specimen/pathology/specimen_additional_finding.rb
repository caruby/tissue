module CaTissue
  class Specimen
    # @quirk caTissue The 1.1.2 class AdditionalFinding is renamed to SpecimenAdditionalFinding in 1.2.
    # Alias the SpecimenAdditionalFinding Ruby class to AdditionalFinding for backward compatibility.
    module Pathology
      class SpecimenAdditionalFinding
        Pathology.const_set(:AdditionalFinding, self)
        logger.debug { "Aliased the Specimen pathology annotation class SpecimenAdditionalFinding to AdditionalFinding." }
      end
    end
  end
end
