require 'caruby/domain/resource_module'
require 'catissue/annotation/annotation'
require 'catissue/annotation/annotation_class'
require 'catissue/annotation/proxy'
require 'catissue/annotation/proxy_class'

module CaTissue
  module AnnotationModule
    include CaRuby::ResourceModule

    # @return [AnnotationClass] the annotation proxy class 
    attr_accessor :proxy

    def self.extend_module(mod, hook, opts)
      mod.extend(self)
      mod.initialize_annotation(hook, opts)
    end
    
    def initialize_annotation(hook, opts)
      extend(CaRuby::ResourceModule)
      @java_package = opts[:package]
      @svc_nm = opts[:service]
      create_mixin
      # Proxy initialization has to set proxy mid-initialization.
      # That is why @proxy is writable. Although setting @proxy
      # is redundant here, do so since that is the better approach
      # and will be necessary if and when proxy init is cleaned up.
      @proxy = import_proxy(hook)
      @proxy.extend(Annotation::ProxyClass)
    end
    
    # Ensures that each primary annotation in this module has a proxy reference attribute.
    # The primary annotation creates a proxy attribute if necessary.
    def ensure_proxy_attributes_are_defined
      @rsc_classes.each { |klass| klass.ensure_primary_has_proxy(@proxy) }
    end
    
    # Builds an annotation dependency hierarchy starting at the proxy.
    def add_annotation_dependents
      @proxy.add_annotation_dependents
    end
    
    def persistence_service
      @ann_svc ||= Database.instance.annotator.create_annotation_service(@svc_nm)
    end
    
    private
    
    def create_mixin
      module_eval("module Resource; end")
      @mixin = const_get('Resource')
      mod = self
      @mixin.module_eval do
        include Annotation
        
        @domain_module = mod
        def self.included(klass)
          super
          @domain_module.add_class(klass)
          klass.extend(AnnotationClass)
          logger.debug { "#{klass.qp} marked as an annotation class." }
        end
      end
    end
    
    def import_proxy(hook)
      # the annotation proxy Java class name
      proxy_nm = hook.name.demodulize
      logger.debug { "Importing #{hook.qp} annotation #{qp} hook proxy Java class..." }
      begin
        const_get(proxy_nm)
      rescue CaRuby::JavaIncludeError
        raise AnnotationError.new("#{hook.qp} annotation #{qp} does not have a hook proxy class - #{$!}")
      end
    end
  end
end
