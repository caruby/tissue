require 'caruby/util/properties'
require 'caruby/migration/migrator'
require 'catissue/resource'
require 'catissue/database/controlled_values'
require 'catissue/database/controlled_value_finder'

module CaTissue
  # Migrates a CSV extract to caTissue. See the {#initialize} documentation for usage options.
  #
  # See the Galena Cancer Center Tissue Bank Migration Example for further information
  # about how the options tailor migration, esp. the use of the field mappings and shims.
  class Migrator < CaRuby::Migrator
    # Creates a new Migrator with the given options.
    #
    # This migrator must include sufficient information to build a well-formed migration target object.
    # For example, if the target object is a new SpecimenCollectionGroup, then the migration must also be
    # able to build that SCG's CollectionProtocolRegistration. The CPR in turn must either exist in the
    # database or the migration must build a Participant and a CollectionProtocol.
    # 
    # @option (see CaRuby::Migrator#initialize)
<<<<<<< HEAD
    # @option opts [String] :tissue_sites the tissue site mapping file
    # @option opts [String] :diagnoses the diagnosis mapping file
     def initialize(opts={})
=======
    # @option opts [String] :database target application {CaRuby::Database}
    # @option opts [String] :target required target domain class
    # @option opts [String] :input required source file to migrate
    # @option opts [String] :shims optional array of shim files to load
    # @option opts [String] :unique makes migrated objects unique object for testing
    #   mix-in do not conflict with existing or future objects
    # @option opts [String] :bad write each invalid record to the given file and continue migration
    # @option opts [String] :offset zero-based starting source record number to process (default 0)
    def initialize(opts={})
>>>>>>> parent of 745f9e3... Clean up documentation.
      # if there is a configuration file, then add config options into the parameter options
      conf_file = opts.delete(:file)
      if conf_file then
        conf = CaRuby::Properties.new(conf_file, :array => [:shims])
        # add config options but don't override the parameter options
        opts.merge!(conf, :deep) { |key, oldval, newval| oldval }
      end
      # open the log file before building structure
      log_file = opts[:log]
      CaRuby::Log.instance.open(log_file, :debug => opts[:debug]) if log_file

      # tailor the options
      opts[:name] ||= NAME
      opts[:database] ||= CaTissue::Database.instance
      
      # the shims file(s)
      opts[:shims] ||= []
      shims = opts[:shims] ||= []
      # make a single shims file into an array
      shims = opts[:shims] = [shims] unless shims.collection?
      # prepend this migrator's shims
      shims.unshift(MIGRATABLE_SHIM)

      # If the unique option is set, then append the CaTissue-specific uniquifier shim.
      if opts[:unique] then
        # add the uniquify shim
        shims << UNIQUIFY_SHIM
        logger.debug { "Migrator added uniquification shim #{UNIQUIFY_SHIM}." }
      end

      # call the CaRuby::Migrator initializer with the augmented options
      super

      # The remaining options are handled by this CaTissue::Migrator subclass.

      # The tissue site CV look-up option.
      tissue_sites = opts[:tissue_sites]
      if tissue_sites then
        CaTissue::SpecimenCharacteristics.tissue_site_cv_finder = ControlledValueFinder.new(:tissue_site, tissue_sites)
        logger.info("Migrator enabled tissue site controlled value lookup.")
      end

      # The clinical diagnosis CV look-up option.
      diagnoses = opts[:diagnoses]
      if diagnoses then
        CaTissue::SpecimenCollectionGroup.diagnosis_cv_finder = ControlledValueFinder.new(:clinical_diagnosis, diagnoses)
        logger.info("Migrator enabled clinical diagnosis controlled value lookup.")
      end
    end

    private
    # The default name of this migrator.
    NAME = 'caTissue Migrator'

    # The built-in caTissue migration shims.
    MIGRATABLE_SHIM = File.join(File.dirname(__FILE__), 'migratable.rb')
    
    UNIQUIFY_SHIM = File.join(File.dirname(__FILE__), 'uniquify')
        
    # The context module is determined as follows:
<<<<<<< HEAD
    # * for an {Annotation} target class, the context module is the annotated class's domain_module
    # * otherwise, delegate to +CaRuby::Migrator+.
=======
    # * for an {Annotation} target class, the context module is the annotated class's {ResourceClass#domain_module}
    # * otherwise, delegate to {CaRuby::Migrator}.
>>>>>>> parent of 745f9e3... Clean up documentation.
    #
    # @return (see CaRuby::Migrator#context_module)
    def context_module
      @target_class < Annotation ? @target_class.hook.domain_module : super
    end
    
    # Clears the migration protocol CPR and SCG references.
    # This action frees up memory for the next iteration, thereby ensuring that migration is an
    # O(1) rather than O(n) operation.
    def clear(target)
      pcl = target_protocol(target) || return
      logger.debug { "Clearing #{pcl.qp} CPR and SCG references..." }
      @database.lazy_loader.suspend do
        pcl.registrations.clear
        pcl.events.each { |event| event.specimen_collection_groups.clear }
      end
    end
    
    def target_protocol(target)
      case target
        when CaTissue::SpecimenCollectionGroup then
          cpe = target.collection_protocol_event
          cpe.collection_protocol if cpe
        when CaTissue::Specimen then target_protocol(target.specimen_collection_group)
      end
    end
  end
end