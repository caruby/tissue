module CaTissue
  class Specimen
    class Pathology
      # caTissue alert - The 1.1 class GleasonScore is renamed to ProstateSpecimenGleasonScore in 1.2.
      # Alias the Ruby class constant for forward and backaward compatibility.
      begin
        resource_import Java::pathology_specimen.ProstateSpecimenGleasonScore
        const_set(:GleasonScore, ProstateSpecimenGleasonScore)
        logger.debug { "Aliased the Specimen pathology annotation class ProstateSpecimenGleasonScore to GleasonScore." }
      rescue NameError
        logger.debug { "SpecimenGleasonScore pathology annotation class not found; attempting to import the caTissue 1.1 GleasonScore variant..." }
        resource_import Java::pathology_specimen.GleasonScore
        const_set(:ProstateSpecimenGleasonScore, GleasonScore)
        logger.debug { "Aliased the caTissue 1.1 Specimen pathology annotation class GleasonScore class to the renamed 1.2 ProstateSpecimenGleasonScore." }
      end
    end
  end
end