require 'caruby/util/properties'
require 'caruby/migration/migrator'
require 'catissue/resource'
require 'catissue/database/controlled_values'
require 'catissue/database/controlled_value_finder'

module CaTissue
  # Even though Migratable is included in CaRuby::Resource, the Migratable methods
  # are not appended to a CaTissue Resource class since the class already includes
  # CaRuby::Resource. In Ruby, A include B followed by B include C does not imply
  # that A includes C. Therefore, notify CaTissue that its mixin has changed and each
  # loaded class must reinclude the mixin.
  CaTissue.mixin_changed
  
  # Migrates a CSV extract to caTissue. See the {#initialize} documentation for usage options.
  #
  # See the Galena Cancer Center Tissue Bank Migration Example for further information
  # about how the options tailor migration, esp. the use of the field mappings and shims.
  class Migrator < CaRuby::Migrator
    # The default name of this migrator.
    NAME = 'caTissue Migrator'

    DEF_CONF_FILE = File.join('conf', 'migration.yaml')

    # The built-in caTissue migration shims.
    SHIM_FILE = File.join(File.dirname(__FILE__), 'shims.rb')

    # Creates a new Migrator with the given options.
    #
    # This migrator must include sufficient information to build a well-formed migration target object.
    # For example, if the target object is a new SpecimenCollectionGroup, then the migration must also be
    # able to build that SCG's CollectionProtocolRegistration. The CPR in turn must either exist in the
    # database or the migration must build a Participant and a CollectionProtocol.
    # 
    # @option (see CaRuby::Migrator#initialize)
    def initialize(opts={})
      # if there is a configuration file, then add config options into the parameter options
      conf_file = opts.delete(:file)
      if conf_file then
        conf = CaRuby::Properties.new(conf_file, :array => [:shims])
        # add config options but don't override the parameter options
        opts.merge!(conf, :deep) { |key, oldval, newval| oldval }
      end
      
      
      # TODO - move opt parsing to CaTissue::CLI::Migrate and call that from test cases
      # Migrate then calls this Migrator with parsed options
      
      
      # open the log file before building structure
      log_file = opts[:log]
      CaRuby::Log.instance.open(log_file, :debug => opts[:debug]) if log_file

      # tailor the options
      opts[:name] ||= NAME
      opts[:database] ||= CaTissue::Database.instance
      # prepend this migrator's shims
      shims = opts[:shims] ||= []
      shims.unshift(SHIM_FILE)

      # call the CaRuby::Migrator initializer with the augmented options
      super

      # the options specific to this CaTissue::Migrator subclass
      tissue_sites = opts[:tissue_sites]
      if tissue_sites then
        CaTissue::SpecimenCharacteristics.tissue_site_cv_finder = ControlledValueFinder.new(:tissue_site, tissue_sites)
        logger.info("Migrator enabled controlled value lookup.")
      end
      diagnoses = opts[:diagnoses]
      if diagnoses then
        CaTissue::SpecimenCollectionGroup.diagnosis_cv_finder = ControlledValueFinder.new(:clinical_diagnosis, diagnoses)
        logger.info("Migrator enabled controlled value lookup.")
      end
    end

    private
    
    # Clears the migration protocol CPR and SCG references.
    # This action frees up memory for the next iteration, thereby ensuring that migration is an
    # O(1) rather than O(n) operation.
    def clear(target)
      pcl = target_protocol(target) || return
      logger.debug { "Clearing #{pcl.qp} CPR and SCG references..." }
      pcl.suspend_lazy_loader do
        pcl.registrations.clear
        pcl.events.each { |event| event.suspend_lazy_loader { event.specimen_collection_groups.clear } }
      end
    end
    
    def target_protocol(target)
      case target
      when CaTissue::SpecimenCollectionGroup then
        cpe = target.collection_protocol_event
        cpe.collection_protocol if cpe
      when CaTissue::Specimen then
        target_protocol(target.specimen_collection_group)
      end
    end
  end
end