module CaTissue
  class AbstractSpecimenCollectionGroup
    add_attribute_aliases(
      :diagnosis => :clinical_diagnosis,
      :site => :specimen_collection_site,
      :collection_site => :specimen_collection_site
    )

    add_attribute_defaults(
      :activity_status => 'Active',
      :clinical_status => 'Not Specified',
      :clinical_diagnosis => 'Not Specified'
    )

    add_mandatory_attributes(:activity_status)

    # Overrides +Jinx::Resource.each_dependent+ to exclude Specimens or SpecimenRequirements
    # with a parent, since the parent is the immediate Specimen or SpecimenRequirement owner.
    #
    # @yield (see Jinx::Resource#each_dependent)
    # @yieldparam (see Jinx::Resource#each_dependent)
    def each_dependent
      super { |dep| yield dep unless AbstractSpecimen === dep and dep.parent }
    end
  end
end