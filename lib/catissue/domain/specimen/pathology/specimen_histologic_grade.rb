module CaTissue
  class Specimen
    class Pathology
      # @quirk caTissue The 1.1 class HistologicGrade is renamed to SpecimenHistologicGrade in 1.2.
      #   Alias the Ruby class constant for forward and backaward compatibility.
      begin
        resource_import Java::pathology_specimen.SpecimenHistologicGrade
        const_set(:HistologicGrade, SpecimenHistologicGrade)
        logger.debug { "Aliased the Specimen pathology annotation class SpecimenHistologicGrade to HistologicGrade." }
      rescue NameError
        logger.debug { "SpecimenHistologicGrade pathology annotation class not found; attempting to import the caTissue 1.1 HistologicGrade variant..." }
        resource_import Java::pathology_specimen.HistologicGrade
        const_set(:SpecimenHistologicGrade, HistologicGrade)
        logger.debug { "Aliased the caTissue 1.1 Specimen pathology annotation class HistologicGrade class to the renamed 1.2 SpecimenHistologicGrade." }
      end
    end
  end
end
