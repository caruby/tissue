require 'caruby/domain'
require 'catissue/annotation/annotation'
require 'catissue/annotation/annotation_class'
require 'catissue/annotation/proxy'
require 'catissue/annotation/proxy_class'
require 'catissue/annotation/de_integration'

module CaTissue
  module AnnotationModule
    # @return [<AnnotationClass>] this module's annotation classes
    attr_reader :annotation_classes

    # @return [ProxyClass] the annotation proxy class 
    attr_reader :proxy
    
    # @return [String] the group short name
    attr_reader :group
      
    # @return [Class] the hook-annotation association class, or nil for 1.1.x caTissue
    attr_reader :record_entry_class
      
    # @return [Symbol] the {#record_entry_class} hook writer method, or nil for 1.1.x caTissue
    attr_reader :record_entry_hook_writer

    # @param [AnnotationModule] mod the annotation module to build
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
    def self.extend_module(mod, hook, opts, &proxy_builder)
      mod.extend(self)
      mod.initialize_annotation(hook, opts, &proxy_builder)
    end
    
    # Builds the annotation module.
    # This method intended to be called only by {AnnotationModule.extend_module}.
    #
    # @param (see AnnotationModule.extend_module)
    # @yield (see AnnotationModule.extend_module)
    # @yieldparam (see AnnotationModule.extend_module)
    def initialize_annotation(hook, opts)
      logger.debug { "Building #{hook.qp} annotation #{qp}..." }
      # Make this module a CaRuby Domain
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
      @ann_svc ||= Database.instance.annotator.create_annotation_service(self, @svc_nm)
    end
    
    # This method implements the {CaRuby::MetadataLoader#add_metadata} callback to ensure
    # that the metadata load is complete.
    #
    # Annotation classes are introspected, but the annotation constant is not set properly
    # in the annotation module. This occurs sporadically, e.g. in the PSBIN migration_test
    # test_biopsy_target test case the NewDiagnosisHealthAnnotation class is introspected
    # but when subsequently referenced by the migrator, the NewDiagnosisHealthAnnotation
    # class is not introspected and the class object id differs from the original class
    # object id. The cause of this bug is a complete mystery. The work-around is for this
    # callback to call const_get on the given class. This is a seemingly unnecessary
    # action to take, but was the most reasonable remedy discovered after two days of
    # futile investigation. The const_get can only be done with annotation classes,
    # and breaks non-annotation classes.
    #
    # TODO - refactor the doman class introspector yet again to simplify and unravel this bug.
    #
    def metadata_added(klass)
      const_get(klass.name.demodulize)
    end
        
    private
    
    # The location of the domain class definitions.
    DOMAIN_DIR = File.dirname(__FILE__) + '/../domain'
    
    # @param (see #initialize_annotation)
    def enable_metadata(hook, opts)
      # the annotation Ruby source files
      dir = File.join(DOMAIN_DIR, hook.name.demodulize.underscore, name.demodulize.underscore)
      opts[:directory] = dir if File.directory?(dir)
      opts[:mixin] = Annotation
      opts[:metadata] = Proc.new { |klass| AnnotationClass.extend_class(klass, self) }
      CaRuby::Domain.extend_module(self, opts)
    end
    
    # Sets the record entry instance variables for the given class name, if it exists
    # as a {Annotation::DEIntegration} proxy class. caTissue v1.1.x does not have
    # a record entry class.
    #
    # @param [String] the record entry class name specified in the
    #   {CaTissue::AnnotatableClass#add_annotation} +:record_entry+ option
    def import_record_entry_class(klass, hook)
      @record_entry_class = const_get(klass.name.demodulize.to_sym)
      @record_entry_hook_writer = "#{hook.name.demodulize.underscore}=".to_sym
    end
    
    # @param hook (see #initialize_annotation)
    # @param [String] name the demodulized name of the proxy class
    #   (default is the demodulized hook class name)
    def import_proxy(hook, name=nil)
      name ||= hook.name.demodulize
      logger.debug { "Importing #{qp} #{hook.qp} annotation proxy..." }
      begin
        klass = const_get(name.to_sym)
      rescue NameError => e
        CaRuby.fail(AnnotationError, "#{hook.qp} annotation #{qp} does not have a hook proxy class", e)
      end
      klass.extend(Annotation::ProxyClass)
      klass.hook = hook
      logger.debug { "Built #{name} #{hook.qp} annotation proxy #{klass}." }
      klass
    end
  end
end
