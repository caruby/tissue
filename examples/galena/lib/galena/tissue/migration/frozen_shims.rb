# load the defaults file in the seed directory
require File.join(File.dirname(__FILE__), '..', 'seed', 'defaults')

module CaTissue
  # Declare the classes modified for migration.
  shims TissueSpecimen, CollectionProtocolRegistration, StorageContainer 
  
  class StorageContainer
    # Creates the migrated box in the database, if necessary.
    #
    # @param [{Symbol => Object}] row the input row field => value hash
    # @param [<Resource>] migrated the migrated instances
    def migrate(row, migrated)
      super
      # Fetch the box from the database, if it exists.
      # Otherwise, create the box.
      find or create_galena_box
    end
    
    private

    # Creates a new box of type {Galena::Seed::Defaults#box_type} in a freezer of type
    # {Galena::Seed::Defaults#freezer_type}.
    # 
    # @return [StorageContainer] the new box
    def create_galena_box
      defs = Galena::Seed.defaults
      # the box container type
      self.container_type = defs.box_type
      # the required box site
      self.site = defs.tissue_bank
      # A freezer with a slot for the box.
      frz = defs.freezer_type.find_available(site, :create)
      # Add the box to the first open slot in the first unfilled rack in the freezer.
      frz << self
      logger.debug { "Placed the tissue box #{self} in freezer #{frz}." }
      logger.debug { "Creating the tissue box #{self} in the database..." }
      create
    end
  end
end