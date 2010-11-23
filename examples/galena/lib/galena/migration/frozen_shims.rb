require 'galena/seed/defaults'

module CaTissue

  # Declares the classes modified for migration.
  shims TissueSpecimen, CollectionProtocolRegistration, StorageContainer 

  class TissueSpecimen
    # Sets the specimen type to +Frozen Tissue+.
    #
    # @param (see CaRuby::Migratable#migrate)
    def migrate(row, migrated)
      super
      self.specimen_type = 'Frozen Tissue'
    end
  end
  
  class CollectionProtocolRegistration
    # Sets this CPR's protocol to the pre-defined {Galena::Migration::Defaults#protocol}.
    #
    # @param (see CaRuby::Migratable#migrate)
    def migrate(row, migrated)
      super
      self.protocol = Galena::Seed.defaults.protocol
    end
  end

  class StorageContainer
    # Creates the migrated box in the database, if necessary.
    #
    # @param (see CaRuby::Migratable#migrate)
    def migrate(row, migrated)
      super
      find or create_box
    end
    
    private
    
    # Creates a new box of type {Galena::Migration::Defaults#box_type} in a
    # freezer of type {Galena::Migration::Defaults#freezer_type}.
    # 
    # @return [StorageContainer] the new box
    def create_box
      defs = Galena::Seed.defaults
      self.storage_type = defs.box_type
      self.site = defs.tissue_bank
      # A freezer with a spot for the box
      frz = defs.freezer_type.find_available(site, :create)
      if frz.nil? then raise CaRuby::MigrationError.new("Freezer not available to place #{self}") end
      # Add this box to the first open slot in the first unfilled rack in the freezer.
      frz << self
    end
  end
end