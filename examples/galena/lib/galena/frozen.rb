require File.expand_path('migrator', File.dirname(__FILE__))

module CaTissue
  # Declares the classes modified for migration.
  shims TissueSpecimen, CollectionProtocolRegistration, StorageContainer 
  
  class StorageContainer
    # Creates the migrated box in the database, if necessary.
    #
    # @param (see Jinx::Migratable#migrate)
    def migrate(row, migrated)
      super
      find or create_galena_box
    end
    
    private

    # Creates a new box of type {Galena::Seed#box_type} in a freezer of type
    # {Galena::Seed#freezer_type}.
    # 
    # @return [StorageContainer] the new box
    def create_galena_box
      # the box container type
      self.container_type = Galena::Migrator.administrative_objects.box_type
      # the required box site
      self.site = Galena::Migrator.administrative_objects.tissue_bank
      # A freezer with a slot for the box.
      frz = Galena::Migrator.administrative_objects.freezer_type.find_available(site, :create)
      # Add the box to the first open slot in the first unfilled rack in the freezer.
      frz << self
      logger.debug { "Placed the tissue box #{self} in freezer #{frz}." }
      logger.debug { "Creating the tissue box #{self}..." }
      create
    end
  end
end