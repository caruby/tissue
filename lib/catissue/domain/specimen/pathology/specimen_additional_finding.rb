module CaTissue
  class Specimen
    class Pathology
      # caTissue alert - The 1.1 class AdditionalFinding is renamed to SpecimenAdditionalFinding in 1.2.
      # Alias the Ruby class constant for forward and backaward compatibility.
      begin
        resource_import Java::pathology_specimen.SpecimenAdditionalFinding
        const_set(:AdditionalFinding, SpecimenAdditionalFinding)
        logger.debug { "Aliased the Specimen pathology annotation class SpecimenAdditionalFinding to AdditionalFinding." }
      rescue NameError
        logger.debug { "SpecimenAdditionalFinding pathology annotation class not found; attempting to import the caTissue 1.1 AdditionalFinding variant..." }
        resource_import Java::pathology_specimen.AdditionalFinding
        # caTissue alert - the Specimen additional finding annotation 1.1 method 'details' is renamed to
        # 'specimenDetails' in 1.2.
        const_set(:SpecimenAdditionalFinding, AdditionalFinding)
        logger.debug { "Aliased the caTissue 1.1 Specimen pathology annotation class AdditionalFinding class to the renamed 1.2 SpecimenAdditionalFinding." }
      end
    end
  end
end
