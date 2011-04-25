require 'caruby/migration/migratable'

module CaTissue
  module CollectibleEventParameters
    
    private
    
    # Overrides {CaRuby::Migratable#migratable__target_value} to confer precedence to
    # a SCG over a Specimen when setting this event parameters' owner. If the migrated
    # collection includes both a Specimen and a SCG, then this event parameters
    # +specimen+ reference is ambiguous, but the +specimen_collection_group+ reference
    # is not.
    #
    # @param (see CaRuby::Migratable#migratable__target_value)
    # @return (see CaRuby::Migratable#migratable__target_value)
    def migratable__ambiguous_owner?(attr_md, migrated)
      super and attr_md.to_sym != :specimen_collection_group
    end
  end
end