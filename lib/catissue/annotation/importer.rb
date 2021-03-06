require 'catissue/annotation/annotation'
require 'catissue/annotation/metadata'
require 'catissue/annotation/importer'
require 'catissue/annotation/proxy'
require 'catissue/annotation/proxy_class'
require 'catissue/annotation/de_integration'

module CaTissue
  module Annotation
    # This Annotation Importer module extends the standard +Jinx::Importer+ to import annotation
    # classes. 
    module Importer
      include Jinx::Importer
      
      # @return [<Metadata>] this module's annotation classes
      attr_reader :annotation_classes

      # @return [ProxyClass] the annotation proxy class 
      attr_reader :proxy
    
      # @return [String] the group short name
      attr_reader :group
      
      # @return [ProxyClass] the hook-annotation association class, or nil for 1.1.x caTissue
      attr_reader :record_entry_class
      
      # @return [Symbol] the {#record_entry_class} hook writer method, or nil for 1.1.x caTissue
      attr_reader :record_entry_hook_writer
    
      # Builds this annotation module.
      # This method intended to be called only by {Metadata}.
      #
      # @param [Class] hook the static hook class
      # @param [{Symbol => Object}] the options
      # @option opts [String] :package the DE package name
      # @option opts [String] :service the DE service name
      # @option opts [String] :group the DE group short name
      # @option opts [String] :record_entry the record entry name class for post-1.1.x caTissue
      # @yield [proxy] makes the hook => proxy reference attribute
      # @yieldparam [ProxyClass] proxy the proxy class
      # @yield [proxy] makes the hook => proxy reference attribute
      # @yieldparam [ProxyClass] proxy the proxy class
      def initialize_annotation(hook, opts)
        logger.debug { "Building #{hook.qp} annotation #{qp}..." }
        # Make this module an annotation-enabled Jinx::Importer 
        enable_metadata(hook, opts)
        @svc_nm = opts[:service]
        @group = opts[:group]
        @annotation_classes = []
        dei = hook.de_integration_proxy_class
        if dei then
          import_record_entry_class(dei, hook)
          pxy_nm = dei.name.demodulize
        end
        @proxy = import_proxy(hook, pxy_nm)
        # Make the hook => proxy reference
        yield @proxy
        # Fill out the dependency hierarchy.
        @proxy.build_annotation_dependency_hierarchy
        # Print all known annotation classes.
        @annotation_classes.each { |klass| logger.info(klass.pp_s) }
        logger.debug { "Built #{hook.qp} annotation #{qp}." }
      end
    
      # @return (ProxyClass#hook)
      def hook
        @proxy.hook
      end
    
      # @return [CaRuby::PersistenceService] this module's application service
      def persistence_service
        @ann_svc ||= Database.current.annotator.create_annotation_service(self, @svc_nm)
      end
    
      private
    
      # The location of the domain class definitions.
      DOMAIN_DIR = File.dirname(__FILE__) + '/../domain'
    
      # @param (see #initialize_annotation)
      def enable_metadata(hook, opts)
        # Add introspection and annotation capability.
        include Annotation
        # Make this module an annotation importer.
        extend Jinx::Importer
        # Each annotation class extends Annotation::Metadata.
        @metadata_module = Metadata
        # The annotation parent module is the hook domain module.
        @parent_importer = hook.domain_module
        # the package name
        package(opts[:package])
        # the annotation Ruby source files
        dir = File.join(DOMAIN_DIR, hook.name.demodulize.underscore, name.demodulize.underscore)
        definitions(dir) if File.directory?(dir)
      end

      # Augments +Jinx::Importer.add_metadata+ to add annotation meta-data to the introspected class.
      #
      # @param [Metadata] klass the domain class
      def add_metadata(klass)
        super
        # Build the annotation metadata.
        klass.add_annotation_metadata(self)
        # Register the annotation class.
        annotation_classes << klass
        
        # TODO - uncomment and confirm that the test_biopsy_target works.
        # # Annotation classes are introspected, but the annotation constant is not set properly
        # # in the annotation module. This occurs sporadically, e.g. in the PSBIN migration_test
        # # test_biopsy_target test case the NewDiagnosisHealthAnnotation class is introspected
        # # but when subsequently referenced by the migrator, the NewDiagnosisHealthAnnotation
        # # class object id differs from the original class object id. However, the analogous
        # # test_surgery_target does not exhibit this defect.
        # #
        # # The cause of this bug is a complete mystery. The work-around is to get the constant.
        # # below. This is a seemingly unnecessary action to take, but was the most reasonable
        # # remedy. The const_get can only be done with annotation classes, and breaks
        # # non-annotation classes.
        # const_get(klass.name.demodulize)
      end
    
      # Sets the record entry instance variables for the given class name, if it exists
      # as a {Annotation::DEIntegration} proxy class. caTissue v1.1.x does not have
      # a record entry class.
      #
      # @param [String] the record entry class name specified in the
      #   {CaTissue::Metadata#add_annotation} +:record_entry+ option
      def import_record_entry_class(klass, hook)
        @record_entry_class = const_get(klass.name.demodulize.to_sym)
        @record_entry_hook_writer = "#{hook.name.demodulize.underscore}=".to_sym
      end
    
      # @param hook (see #initialize_annotation)
      # @param [String] name the demodulized name of the proxy class
      #   (default is the demodulized hook class name)
      def import_proxy(hook, name=nil)
        name ||= hook.name.demodulize
        logger.debug { "Importing the #{qp} #{hook.qp} annotation proxy..." }
        begin
          klass = const_get(name.to_sym)
        rescue NameError => e
          logger.error("#{hook.qp} annotation #{qp} does not have a hook proxy class - " + $!)
          raise
        end
        klass.extend(Annotation::ProxyClass)
        klass.hook = hook
        logger.debug { "Built the #{name} #{hook.qp} annotation proxy #{klass}." }
        klass
      end
    end
  end
end
