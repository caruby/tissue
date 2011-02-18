module CaTissue
  java_import('edu.wustl.catissuecore.domain.AbstractSpecimenCollectionGroup')

  class AbstractSpecimenCollectionGroup
    include Resource

    add_attribute_aliases(:diagnosis => :clinical_diagnosis)

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