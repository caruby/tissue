# This file is the entry point included by applications which use a CaTissue application service.
require 'uom'
require 'jinx'
require 'jinx/json'
require 'jinx/json/serializer'
require 'caruby'
require 'caruby/resource'
require 'catissue/annotation/annotatable'
require 'catissue/annotation/annotatable_class'
require 'catissue/helpers/properties_loader'

# The caTissue domain package metadata mix-in. Each domain class automatically
# includes this CaTissue module when it is referenced.
module CaTissue
  include Jinx::JSON::Serializer, Annotatable, CaRuby::Resource, Jinx::Resource
  
  # The domain class definition Ruby mix-ins.
  # @private
  SRC_DIR = File.dirname(__FILE__) + '/catissue/domain'
  
  # Inject the importer and application properties loader into this CaTissue module.
  extend PropertiesLoader

  # The caTissue Java package name.
  packages 'edu.wustl.catissuecore.domain', 'edu.wustl.common.domain'
  
  # The JRuby mix-ins are in the domain subdirectory.
  definitions SRC_DIR
  
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
  
  # Makes the introspected class persistable and annotatable.
  #
  # @param [Class] klass the caTissue domain class
  def self.add_metadata(klass)
    super
    klass.extend(AnnotatableClass)
  end
end
