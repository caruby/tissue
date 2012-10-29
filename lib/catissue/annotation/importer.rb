require 'catissue/annotation/annotation'
require 'catissue/annotation/metadata'
require 'catissue/annotation/integration'

# pre-2.0 cruft
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

      # @return [IntegrationClass] the annotation integration class 
      attr_reader :integration_class
      
      alias :proxy :integration_class
  
      # @return [String] the group short name
      attr_reader :group
  
      # @return [Class] the optional annotation class mix-in module
      attr_reader :mixin
    
      # Builds this annotation module.
      # This method is intended to only be called by the hook class.
      #
      # @param [Class] hook the static hook class
      # @param [{Symbol => Object}] the options
      # @option opts [String] :packages the DE package names
      # @option opts [String] :group the DE group short name
      # @option opts [Module] :mixin the optional mix-in to include in the annotation classes
      def initialize_annotation(hook, opts)
        logger.debug { "Building the #{hook.qp} annotation #{qp}..." }
        # Make this module an annotation-enabled Jinx::Importer 
        enable_metadata(hook, opts)
        @group = opts[:group]
        @mixin = opts[:mixin]
        @annotation_classes = []
        # the integration class
        begin
          pxy_nm = opts[:proxy_name] || "#{hook.name.demodulize}RecordEntry"
          @integration_class = integration_module.const_get(pxy_nm)
        rescue NameError
          logger.error("The #{hook.qp} #{self} annotation integration class #{hook.name.demodulize}RecordEntry was not found in #{integration_module}.")
          raise
        end
        logger.debug { "The #{hook.qp} #{self} annotation integration class is #{@integration_class}." }
        # the hook -> integration property
        hip = hook.properties.detect { |p| @integration_class <= p.type }
        if hip.nil? then
          raise AnnotationError.new("#{hook.qp} -> #{@integration_class} hook -> integration property was not found")
        end
        hook.add_dependent_property(hip)
        @integration_class.integrate(self)
        logger.debug { "Built the #{hook.qp} annotation #{qp}." }
        # Print all known annotation classes.
        logger.info { "#{qp} integration class:\n#{@integration_class.pp_s}" }
        logger.info { "#{qp} annotation classes:" }
        @annotation_classes.each { |klass| logger.info(klass.pp_s) }
      end
    
      # @return [Class] the hook class
      def hook_type
        @integration_class.hook_type
      end
      
      alias :hook :hook_type
    
      private
    
      # The location of the hook domain class definitions.
      DOMAIN_DIR = File.dirname(__FILE__) + '/../domain'
      
      def integration_module
        Integration
      end
      
      # @param (see #initialize_annotation)
      def enable_metadata(hook, opts)
        # Add annotation capability.
        include Annotation
        # Make this module an annotation importer.
        extend Jinx::Importer
        # Each annotation class extends Annotation::Metadata.
        @metadata_module = Metadata
        # The annotation parent module is the hook domain module.
        @parent_importer = hook.domain_module
        # the package name 
        pkgs = opts[:packages]
        String === pkgs ? package(pkgs) : packages(*pkgs)
        # the annotation Ruby source files
        dirs = opts[:definitions] || default_definitions_directory(hook)
        definitions(*dirs)
      end
      
      # @return [String, nil] the +domain/+*hook*+/+*annotation* source directory, if it exists
      def default_definitions_directory(hook)
        dir = File.join(DOMAIN_DIR, hook.name.demodulize.underscore, name.demodulize.underscore)
        dir if File.directory?(dir)
      end

      # Augments +Jinx::Importer.add_metadata+ to add annotation meta-data to the introspected class.
      # The annotation meta-data is only added to concrete classes, since an abstract class might
      # be common to several annotations.
      #
      # @param [Metadata] klass the domain class
      def add_metadata(klass)
        super
        unless klass.abstract? then
          # Build the annotation metadata.
          klass.add_annotation_metadata(self)
          # Register the annotation class.
          @annotation_classes << klass
        end
      end
    end
  end
end
