module CaTissue
  class Specimen
    module Pathology
      # @quirk caTissue The 1.1.2 class GleasonScore is renamed to ProstateSpecimenGleasonScore in 1.2.
      #   Alias the ProstateSpecimenGleasonScore Ruby class to GleasonScore for backward compatibility.
      class ProstateSpecimenGleasonScore
        Pathology.const_set(:GleasonScore, self)
        logger.debug { "Aliased the Specimen pathology annotation class ProstateSpecimenGleasonScore to GleasonScore." }
      end
    end
  end
end
