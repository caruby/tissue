require 'caruby/domain/resource_module'
require 'catissue/annotation/annotation'
require 'catissue/annotation/annotation_class'
require 'catissue/annotation/proxy'
require 'catissue/annotation/proxy_class'
require 'catissue/annotation/de_integration'

module CaTissue
  module AnnotationModule
    include CaRuby::ResourceModule

    # @return [AnnotationClass] the annotation proxy class 
    attr_accessor :proxy
      
    # @return [Class] the hook-annotation association class, or nil for 1.1.x caTissue
    attr_reader :record_entry_class
      
    # @return [Symbol] the {#record_entry_class} hook writer method, or nil for 1.1.x caTissue
    attr_reader :record_entry_hook_writer

    # @param [AnnotationModule] mod the annotation module to build
    # @param [Class] hook the static hook class
    # @param [{Symbol => Object}] the options
    # @option opts [String] :package the DE package name
    # @option opts [String] :service the DE service name
    # @option opts [String] :record_entry the record entry name class for post-1.1.x caTissue
    def self.extend_module(mod, hook, opts)
      mod.extend(self)
      mod.initialize_annotation(hook, opts)
    end
    
    def initialize_annotation(hook, opts)
      logger.debug { "Building #{hook.qp} annotation #{qp}..." }
      @java_package = opts[:package]
      @svc_nm = opts[:service]
      create_mixin(hook)
      # Proxy initialization has to set proxy mid-initialization.
      # That is why @proxy is writable. Although setting @proxy
      # is redundant here, do so since that is the better approach
      # and will be necessary if and when proxy init is cleaned up.
      rec_entry = opts[:record_entry]
      if rec_entry then
        if Annotation::DEIntegration.const_defined?(rec_entry) then
          @record_entry_class = Annotation::DEIntegration.const_get(rec_entry)
          @record_entry_hook_writer = "#{hook.name.demodulize.underscore}=".to_sym
        else
          logger.warn("Ignored missing annotation #{name} record entry class #{rec_entry}.")
          rec_entry = nil
        end
      end
      @proxy = import_proxy(hook, rec_entry)
      logger.debug { "Building #{name} #{hook.qp} annotation proxy #{@proxy.class.name}..." }
      @proxy.extend(Annotation::ProxyClass)
      logger.debug { "Built #{hook.qp} annotation #{qp}." }
    end
    
    # Ensures that each primary annotation in this module has a proxy reference attribute.
    # The primary annotation creates a proxy attribute if necessary.
    def ensure_proxy_attributes_are_defined
      logger.debug { "Ensuring that #{qp} primary annotations reference the proxy #{@proxy.qp}..." }
      @rsc_classes.each { |klass| klass.ensure_primary_has_proxy(@proxy) }
    end
    
    # Builds an annotation dependency hierarchy starting at the proxy.
    def add_annotation_dependents
      @proxy.add_annotation_dependents
    end
    
    def persistence_service
      @ann_svc ||= Database.instance.annotator.create_annotation_service(self, @svc_nm)
    end
    
    private
    
    # The location of the domain class definitions.
    DOMAIN_DIR = File.join(File.dirname(__FILE__), '..', 'domain')
    
    def create_mixin(hook)
      module_eval("module Resource; include Annotation; end")
      @mixin = const_get('Resource')
      class << self
        def class_added(klass)
          klass.extend(AnnotationClass)
          logger.debug { "#{klass} marked as an annotation class." }
          if @proxy then klass.ensure_primary_has_proxy(@proxy) end
        end
      end
      ann_subdir = name.demodulize.underscore
      @ann_def_dir = File.join(DOMAIN_DIR, hook.name.demodulize.underscore, ann_subdir)
      load_dir(@ann_def_dir)
    end
    
    # @param hook (see #initialize_annotation)
    # @param [String] name the demodulized name of the proxy class, or nil for caTissue 1.1.x
    def import_proxy(hook, name=nil)
      logger.debug { "Importing #{qp} #{hook.qp} proxy#{' ' + name if name}..." }
      name ||= hook.name.demodulize
      begin
        const_get(name.to_sym)
      rescue CaRuby::JavaIncludeError
      raise
        raise AnnotationError.new("#{hook.qp} annotation #{qp} does not have a hook proxy class - #{$!}")
      end
    end
    
    # Infers the given annotation class's inverses attributes.
    #
    # @param (see ResourceModule#imported)
    def imported(klass)
      klass.infer_inverses
    end
  end
end
