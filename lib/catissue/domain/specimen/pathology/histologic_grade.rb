module CaTissue
  class Specimen
    module Pathology
      # @quirk caTissue The 1.1.2 class HistologicGrade is renamed to SpecimenHistologicGrade in 1.2.
      #   Alias the HistologicGrade Ruby class to SpecimenHistologicGrade for forward compatibility.
      class HistologicGrade
        Pathology.const_set(:SpecimenHistologicGrade, self)
        logger.debug { "Aliased the caTissue 1.1 Specimen pathology annotation class HistologicGrade class to the renamed 1.2 SpecimenHistologicGrade." }
      end
    end
  end
end
