module CaTissue
  resource_import Java::edu.wustl.catissuecore.domain.AbstractSpecimenCollectionGroup

  class AbstractSpecimenCollectionGroup
    add_attribute_aliases(:diagnosis => :clinical_diagnosis, :site => :specimen_collection_site, :collection_site => :specimen_collection_site)

    add_attribute_defaults(:activity_status => 'Active', :clinical_status => 'Not Specified', :clinical_diagnosis => 'Not Specified')

    add_mandatory_attributes(:activity_status)

    # Overrides {CaRuby::Resource#each_dependent} to exclude Specimens or SpecimenRequirements with a parent,
    # since parent is the immediate Specimen or SpecimenRequirement owner.
    #
    # @yield (see CaRuby::Resource#each_dependent)
    # @yieldparam (see CaRuby::Resource#each_dependent)
    def each_dependent
      super { |dep| yield dep unless AbstractSpecimen === dep and dep.parent }
    end

  end
end