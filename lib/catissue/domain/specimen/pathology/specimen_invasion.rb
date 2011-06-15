module CaTissue
  class Specimen
    class Pathology
      # caTissue alert - The 1.1 class Invasion is renamed to SpecimenInvasion in 1.2.
      # Alias the Ruby class constant for forward and backaward compatibility.
      begin
        resource_import Java::pathology_specimen.SpecimenInvasion
        const_set(:Invasion, SpecimenInvasion)
        logger.debug { "Aliased the Specimen pathology annotation class SpecimenInvasion to Invasion." }
      rescue NameError
        logger.debug { "SpecimenInvasion pathology annotation class not found; attempting to import the caTissue 1.1 Invasion variant..." }
        resource_import Java::pathology_specimen.Invasion
        const_set(:SpecimenInvasion, Invasion)
        logger.debug { "Aliased the caTissue 1.1 Specimen pathology annotation class Invasion class to the renamed 1.2 SpecimenInvasion." }
      end
    end
  end
end
