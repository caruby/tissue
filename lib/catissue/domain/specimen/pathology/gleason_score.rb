module CaTissue
  class Specimen
    class Pathology
      # @quirk caTissue The 1.1 class GleasonScore is renamed to ProstateSpecimenGleasonScore in 1.2.
      #   Alias the GleasonScore Ruby class constant to ProstateSpecimenGleasonScore forward compatibility.
      class GleasonScore
        Pathology.const_set(:ProstateSpecimenGleasonScore, self)
        logger.debug { "Aliased the caTissue 1.1 Specimen pathology annotation class GleasonScore class to the renamed 1.2 ProstateSpecimenGleasonScore." }
      end
    end
  end
end
