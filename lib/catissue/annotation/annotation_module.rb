require 'caruby/domain'
require 'catissue/annotation/annotation'
require 'catissue/annotation/annotation_class'
require 'catissue/annotation/proxy'
require 'catissue/annotation/proxy_class'
require 'catissue/annotation/de_integration'

module CaTissue
  module AnnotationModule
    include CaRuby::Domain

    # @return [ProxyClass] the annotation proxy class 
    attr_reader :proxy
    
    # @return [String] the group short name
    attr_reader :group
      
    # @return [Class] the hook-annotation association class, or nil for 1.1.x caTissue
    attr_reader :record_entry_class
      
    # @return [Symbol] the {#de_integration_proxy_class} hook writer method, or nil for 1.1.x caTissue
    attr_reader :record_entry_hook_writer

    # @param [AnnotationModule] mod the annotation module to build
    # @param [Class] hook the static hook class
    # @param [{Symbol => Object}] the options
    # @option opts [String] :package the DE package name
    # @option opts [String] :service the DE service name
    # @option opts [String] :group the DE group short name
    # @option opts [String] :record_entry the record entry name class for post-1.1.x caTissue
    def self.extend_module(mod, hook, opts)
      mod.extend(self)
      mod.initialize_annotation(hook, opts)
    end
    
    # Builds the annotation module.
    # This method intended to be called only by {AnnotationModule.extend_module}.
    #
    # @param (see AnnotationModule.extend_module)
    def initialize_annotation(hook, opts)
      logger.debug { "Building #{hook.qp} annotation #{qp}..." }
      pkg = opts[:package]
      @svc_nm = opts[:service]
      @group = opts[:group]
      # Enable the resource metadata aspect.
      md_proc = Proc.new { |klass| AnnotationClass.extend_class(klass, self) }
      CaRuby::Domain::Importer.extend_module(self, :mixin => Annotation, :metadata => md_proc, :package => pkg)
      dei = hook.de_integration_proxy_class
      if dei then
        import_record_entry_class(dei, hook)
        pxy_nm = dei.name.demodulize
      end
      @proxy = import_proxy(hook, pxy_nm)
      load_annotation_class_definitions(hook)
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
    
    private
    
    # The location of the domain class definitions.
    DOMAIN_DIR = File.join(File.dirname(File.dirname(__FILE__)), 'domain')
    
    def load_annotation_class_definitions(hook)
      dir = File.join(DOMAIN_DIR, hook.name.demodulize.underscore, name.demodulize.underscore)
      load_dir(dir)
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
