module CaTissue
  class Specimen
    module Pathology
      # @quirk caTissue The 1.1 class HistologicGrade is renamed to SpecimenHistologicGrade in 1.2.
      #   Alias the SpecimenHistologicGrade Ruby class constant to HistologicGrade backward compatibility.
      class SpecimenHistologicGrade
        Pathology.const_set(:HistologicGrade, self)
        logger.debug { "Aliased the Specimen pathology annotation class SpecimenHistologicGrade to HistologicGrade." }
      end
    end
  end
end
