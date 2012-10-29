# This file is the entry point included by applications which use a CaTissue application service.
require 'jinx'
require 'caruby'
require 'catissue/resource'
require 'catissue/metadata'
require 'catissue/annotation/annotatable'
require 'catissue/annotation/importer'
require 'catissue/annotation/integration'
require 'catissue/helpers/properties_loader'

# The caTissue domain package metadata mix-in. Each domain class automatically
# includes this CaTissue module when it is referenced.
#
# The CaTissue API client must set the application properties described in
# +CaRuby::Database::ACCESS_OPTS+ and +CaRuby::SQLExecutor::ACCESS_OPTS+.
# The application configuration is described in the +README.md+ file.
module CaTissue
  include Annotatable, Resource
  
  # Jinx the module
  extend Jinx::Importer

   # Each CaTissue domain class extends CaTissue::Metadata.
   @metadata_module = Metadata
  
  # Inject the importer and application properties loader into this CaTissue module.
  extend PropertiesLoader

  # The caTissue Java packages.
  #
  # @quirk caTissue 1.2 caTissue 1.2 introduces the auxiliary DE integration package
  #   +edu.wustl.catissuecore.domain.deintegration+ holding the RecordEntry DE proxy
  #   classes.
  #
  # @quirk caTissue 2.0 caTissue 2.0 replaces the auxiliary DE integration package
  #   +edu.wustl.catissuecore.domain.deintegration+ introduced in 1.2 with 
  #   +edu.common.dynamicextensions.domain.integration+.
  #
  # @quirk caTissue 2.0 caTissue 2.0 introduces the auxiliary package
  #   +edu.wustl.catissuecore.domain.processingprocedure+.
  packages 'edu.wustl.catissuecore.domain', 'edu.wustl.common.domain', 'edu.wustl.catissuecore.domain.processingprocedure'
  
  # The JRuby mix-ins are in the domain subdirectory.
  definitions File.dirname(__FILE__) + '/catissue/domain'
    
  # Imports a Java class constant on demand. This method augments +Jinx::Importer.const_missing+
  # with {ActionEventParameters} backward compatibility.
  #
  # @param [Symbol, String] sym the missing constant
  # @return [Class] the imported class
  # @raise [NameError] if the symbol is not an importable Java class
  def self.const_missing(sym)
    begin
      super
    rescue NameError
      # If the class is an EventParameters, then try the SOP annotation introduced in caTissue 2.0.
      if sym.to_s =~ /EventParameters?$/ then
        load_event_parameters(sym) rescue raise
      else
        raise
      end
    end
  end
  
  private
  
  # Tries to load the given class name or symbol as a {ActionEventParameters}.
  #
  # @param [Symbol, String] sym the class name or symbol
  # @return [Class, nil] the imported class, or nil if there is no such SOP DE
  def self.load_event_parameters(sym)
    logger.debug { "Attempting to load #{sym} as a SOP DE class..." }
    begin
      CaTissue::ActionApplication::SOP.const_get(sym)
    rescue
      logger.debug { "#{sym} is not a SOP DE class." }
      raise
    end
  end
  
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
