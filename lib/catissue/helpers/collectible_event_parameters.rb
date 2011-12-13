module CaTissue
  # A CollectibleEventParameters is a SpecimenEventParameters which pertains to Specimen
  # or SpecimenCollectionGroup collection at the point of tissue acquisition from the participant
  # or receival at the tissue bank.
  module CollectibleEventParameters
    # Returns the SpecimenEventParameters in others which matches this CollectibleEventParameters in the scope of an owner Specimen or SCG.
    # This method relaxes +CaRuby::Resource.match_in_owner_scope+ for a CollectibleEventParameters that matches any SpecimenEventParameters
    # in others of the same class, since there can be at most one CollectibleEventParameters of a given class for a given SCG.
    def match_in_owner_scope(others)
      others.detect { |other| minimal_match?(other) }
    end
    
    private
    
    # Injects validation to ensure that a CollectibleEventParameters instance cannot be owned by
    # both a specimen and a SCG.
    # 
    # @param [Class] klass the including class
    def self.included(klass)
      klass.class_eval do
        owner_attributes.each do |attr|
          wtr = attribute_metadata(attr).writer
          redefine_method(wtr) do |base|
            lambda do |obj|
              validate_no_owner_confict(attr, obj)
              send(base, obj)
            end
          end
        end
      end
    end
    
    # @param attribute the owner attribute to set
    # @param obj the owner to set
    # @raise [] if there is already a different owner attribute value
    def validate_no_owner_confict(attribute, obj)
      return if obj.nil?
      self.class.owner_attributes.each do |attr|
        next if attr == attribute
        other = send(attr)
        if other then
          raise CaRuby::ValidationError.new("Cannot add #{qp} to #{attribute} #{obj.qp}, since it is already owned by #{attr} #{other}")
        end
      end
    end
    
    # Overrides +CaRuby::Migratable.migratable__migrate_owner+ to give owner preference to a migrated SCG
    # over a migrated Specimen.
    #
    # @param (see CaRuby::Migratable#migratable__migrate_owner)
    def migratable__migrate_owner(row, migrated, mth_hash=nil)
      migratable__set_scg(row, migrated, mth_hash) or migratable__set_specimen(row, migrated, mth_hash)
    end
    
    # @param (see #migratable__migrate_owner)
    # @return [CaTissue::SpecimenCollectionGroup, nil] the migrated SCG, if any
    def migratable__set_scg(row, migrated, mth_hash=nil)
      attr_md = self.class.attribute_metadata(:specimen_collection_group)
      scg = migratable__target_value(attr_md, row, migrated, mth_hash)
      if scg then self.specimen_collection_group = scg end
    end
    
    # @param (see #migratable__migrate_owner)
    # @return [CaTissue::Specimen, nil] the migrated specimen, if any
    def migratable__set_specimen(row, migrated, mth_hash=nil)
      attr_md = self.class.attribute_metadata(:specimen)
      spc = migratable__target_value(attr_md, row, migrated, mth_hash)
      if spc then self.specimen = spc end
    end
  end
end