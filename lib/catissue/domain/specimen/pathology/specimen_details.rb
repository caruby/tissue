module CaTissue
  class Specimen
    class Pathology
      # @quirk caTissue The 1.1 class Details is renamed to SpecimenDetails in 1.2.
      #   Alias the Ruby class constant for forward and backaward compatibility.
      begin
        resource_import Java::pathology_specimen.SpecimenDetails
        const_set(:Details, SpecimenDetails)
        logger.debug { "Aliased the Specimen pathology annotation class SpecimenDetails to Details." }
      rescue NameError
        logger.debug { "SpecimenDetails pathology annotation class not found; attempting to import the caTissue 1.1 Details variant..." }
        resource_import Java::pathology_specimen.Details
        const_set(:SpecimenDetails, Details)
        logger.debug { "Aliased the caTissue 1.1 Specimen pathology annotation class Details class to the renamed 1.2 SpecimenDetails." }
      end
    end
  end
end
