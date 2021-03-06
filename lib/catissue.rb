# This file is the entry point included by applications which use a CaTissue application service.
require 'jinx'
require 'caruby'
require 'catissue/resource'
require 'catissue/metadata'
require 'catissue/annotation/annotatable'
require 'catissue/helpers/properties_loader'

# The caTissue domain package metadata mix-in. Each domain class automatically
# includes this CaTissue module when it is referenced.
#
# The CaTissue API client must set the application properties described in
# +CaRuby::Database::ACCESS_OPTS+ and +CaRuby::SQLExecutor::ACCESS_OPTS+.
# The application configuration is described in the +README.md+ file.
module CaTissue
  include Annotatable, Resource
  
  extend Jinx::Importer

   # Each CaTissue domain class extends CaTissue::Metadata.
   @metadata_module = Metadata
  
  # Inject the importer and application properties loader into this CaTissue module.
  extend PropertiesLoader

  # The caTissue Java package name.
  packages 'edu.wustl.catissuecore.domain', 'edu.wustl.common.domain'
  
  # The JRuby mix-ins are in the domain subdirectory.
  definitions File.dirname(__FILE__) + '/catissue/domain'
  
  private
  
  # Augments the superclass +Jinx::Importer.configure_importer+ method to first load
  # the properties, build the classpath and initialize the caTissue logger.
  def self.configure_importer
    # Load the properties on demand.
    properties
    # Work around the caTissue logger bug.
    require 'catissue/helpers/log'
    # Delegate to superclass for the heavy lifting.
    super
  end
end
