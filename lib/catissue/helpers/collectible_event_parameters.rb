module CaTissue
  # A CollectibleEventParameters is a SpecimenEventParameters which pertains to Specimen
  # or SpecimenCollectionGroup collection at the point of tissue acquisition from the participant
  # or receival at the tissue bank.
  #
  # @quirk caTissue Although the +specimenCollectionGroup+ property is defined for all
  #   {SpecimenEventParameters}, only the {CollectibleEventParameters} classes can reference
  #   a SCG.
  module CollectibleEventParameters
    # Returns the SpecimenEventParameters in others which matches this CollectibleEventParameters
    # in the scope of an owner Specimen or SCG. This method relaxes +Jinx::Resource.match_in_owner_scope+
    # for a CollectibleEventParameters that matches any SpecimenEventParameters in others of the same
    # class, since there can be at most one CollectibleEventParameters of a given class for a given SCG.
    def match_in_owner_scope(others)
      others.detect { |other| minimal_match?(other) }
    end
    
    private
    
    # Injects validations into the owner writer methods for the following constraints:
    # * a CollectibleEventParameters instance cannot be owned by both a specimen and a SCG.
    # * a Collectible cannot include more than one CollectibleEventParameters instance of a given type.
    #
    # @param [Class] klass the including class
    def self.included(klass)
      klass.class_eval do
        [:specimenCollectionGroup, :specimen].each do |pa|
          wtr = "#{pa}=".to_sym
          redefine_method(wtr) do |base|
            lambda do |obj|
              validate_no_owner_confict(pa, obj)
              validate_exclusivity(pa, obj)
              send(base, obj)
            end
          end
          logger.debug { "Redefined the #{qp} #{pa} method to ensure the owner exclusivity constraints." }
        end
      end
    end
    
    # @param attribute the owner attribute to set
    # @param obj the owner to set
    # @raise [Jinx::ValidationError] if this event parameters object already has a different owner attribute referent
    def validate_no_owner_confict(attribute, obj)
      return if obj.nil?
      self.class.owner_attributes.each do |oa|
        next if oa == attribute
        other = send(oa)
        if other then
          raise Jinx::ValidationError.new("Cannot add #{qp} to #{attribute} #{obj}, since it is already owned by #{other}")
        end
      end
    end
    
    def validate_exclusivity(attribute, obj)
      return if obj.nil?
      inv = self.class.property(attribute).inverse
      other = obj.send(inv).detect { |ep| self.class === ep }
      if other and other != self then
        raise Jinx::ValidationError.new("Cannot add #{self} to #{attribute} #{obj}, since #{obj} already includes #{other}")
      end
    end
    
    # Overrides +Jinx::Migratable.migratable__preferred_owner+ to give preference to
    # a SCG over a Specimen.
    #
    # @param (see Jinx::Migratable#migratable__migrate_owner)
    def migratable__preferred_owner(candidates)
      candidates.detect { |obj| CaTissue::SpecimenCollectionGroup === obj }
    end
  end
end