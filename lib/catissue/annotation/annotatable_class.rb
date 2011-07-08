require 'caruby/util/inflector'
require 'caruby/domain/metadata'
require 'catissue/annotation/annotation_module'
require 'catissue/annotation/de_integration'

module CaTissue
  # Mix-in for extending a caTissue domain class with annotations.
  module AnnotatableClass
    
    # @return [Integer, nil] the the hook class designator that is used by caTissue to persist primary
    #   annotation objects, or nil if this is not a primary annotation class
    attr_reader :entity_id
      
    # @return [Class] the {Annotation::DEIntegration} proxy class (nil for 1.1 caTissue)
    def de_integration_proxy_class
      @de_integration_proxy_class or (superclass.de_integration_proxy_class if superclass < Annotatable)
    end
    
    # Adds +CaRuby::Domain::Metadata+ and {AnnotatableClass} functionality to the given class.
    #
    # @param [Class] the domain class to extend
    def self.extend_class(klass)
      # Enable the class meta-data.
      klass.extend(CaRuby::Domain::Metadata)
      klass.extend(self)
    end
    
    def self.extended(klass)
      super
      # Initialize the class annotation hashes.
      klass.class_eval do
        # Enable the class meta-data.
        # the annotation name => spec hash
        @ann_spec_hash = {}
        # the annotation module => proxy hash
        @ann_mod_pxy_hash = {}
      end
    end

    # @return [Integer, nil] this class's entity id, if it exists, otherwise the superclass effective entity id
    #   if the superclass is an annotation class
    def effective_entity_id
      @entity_id or parent_entity_id
    end

    # Loads the annotations defined for this class if necessary.
    def ensure_annotations_loaded
      # referencing the annotations loads them
      annotation_modules
    end

    # If there is an existing annotation whose proxy accessor is the given symbol, then return true.
    # Otherwise, attempt to import an annotation and return whether the import was successful.
    #
    # @param [Symbol] symbol the potential accessor attribute
    # @return [Boolean] whether there is a corresponding annotation
    def annotation_attribute?(symbol)
      # load annotations if necessary
      ensure_annotations_loaded
      # check for the annotation attribute
      annotation_defined?(symbol)
    end

    # Refines the +CaRuby::Domain::Attributes.toxic_attributes+ to exclude annotation attributes.
    #
    # @return [<Symbol>] the non-annotation unfetched attributes
    def toxic_attributes
      @anntbl_toxic_attrs ||= unfetched_attributes.compose { |attr_md| not attr_md.type < Annotation } 
    end

    # @param [AnnotationModule] mod the annotation module
    # @return [Symbol] the corresponding annotation proxy reference attribute
    def annotation_proxy_attribute(mod)
      @ann_mod_pxy_hash[mod] or
        (superclass.annotation_proxy_attribute(mod) if superclass < Annotatable) or
        raise AnnotationError.new("#{qp} #{mod} proxy attribute not found.")
    end
    
    # Loads the annotations, if necessary, and tries to get the constant again.
    #
    # @param [Symbol] symbol the missing constant
    # @return [AnnotationModule] the imported annotation, if successful
    # @raise [NameError] if the annotation could not be imported
    def const_missing(symbol)
      if annotations_loaded? then
        super
      else
        ensure_annotations_loaded
        const_get(symbol)
      end
    end

    # Filters +CaRuby::Domain::Attributes.loadable_attributes+ to exclude the {#annotation_attributes}
    # since annotation lazy-loading is not supported.
    #
    # @return (see CaRuby::Domain::Attributes#loadable_attributes)
    def loadable_attributes
      @antbl_ld_attrs ||= super.compose { |attr_md| not attr_md.type < Annotation }
    end
    
    def printable_attributes
      @prbl_attrs ||= super.union(annotation_attributes)
    end
    
    def attribute_metadata(attribute)
      begin
        super
      rescue
        if annotation_attribute?(attribute) then
          attribute_metadata(attribute)
        else
          raise
        end
      end
    end
    
    def annotation_attributes
      @ann_attrs ||= append_ancestor_enum(@ann_mod_pxy_hash.enum_values) do |sc|
        sc.annotation_attributes if sc < Annotatable
      end
    end
    
    protected
    
    # @return [<AnnotationModule>] the annotation modules in the class hierarchy
    def annotation_modules
      @ann_mods ||= load_annotations
    end
    
    private
    
    # @param [String] name the proxy record entry class name
    def annotation_proxy_class_name=(name)
      @de_integration_proxy_class = Annotation::DEIntegration.proxy(name)
      if @de_integration_proxy_class then
        # hide the internal caTissue proxy collection attribute
        attr = detect_attribute_with_type(@de_integration_proxy_class)
        if attr then
          remove_attribute(attr)
          logger.debug { "Hid the internal caTissue #{qp} annotation record-keeping attribute #{attr}." }
        end
      else
        logger.debug { "Ignored the missing caTissue #{qp} proxy class name #{name}, presumably unsupported in this caTissue release." }
      end
    end
    
    # Loads the annotation modules in the class hierarchy.
    #
    # @return [<AnnotationModule>] an Enumerable on the loaded annotation modules
    def load_annotations
      @local_ann_mods = load_local_annotations
      superclass < Annotatable ? @local_ann_mods.union(superclass.annotation_modules) : @local_ann_mods
    end
    
    def parent_entity_id
      superclass.entity_id if superclass < Annotatable
    end
    
    def annotatable_class_hierarchy
      class_hierarchy.filter { |klass| klass < Annotatable }
    end
    
    # Declares an annotation scoped by this class.
    #
    # @param [String] name the name of the annotation module
    # @param [{Symbol => Object}] opts the annotation options
    # @option opts [String] :package the package name (default the decapitalized camelized name)
    # @option opts [String] :service the service name (default the decapitalized underscore name)
    def add_annotation(name, opts={})
      # the module symbol
      mod_sym = name.camelize.to_sym
      # the module spec defaults
      pkg = opts[:package] ||= name.camelize(:lower)
      svc = opts[:service] ||= name.underscore
      # add the annotation entry
      @ann_spec_hash[mod_sym] = opts
      logger.info("Added #{qp} annotation #{name} with module #{mod_sym}, package #{pkg} and service #{svc}.")
    end
    
    # @return [Boolean] whether this annotatable class's annotations are loaded
    def annotations_loaded?
      not @ann_mods.nil?
    end
    
    # Loads this class's annotations.
    #
    # @return [<AnnotationModule>] the loaded annotation modules
    def load_local_annotations
      # an annotated class has a hook entity id
      unless @ann_spec_hash.empty? then initialize_annotation_holder end
      # build the annotations
      @ann_spec_hash.map { |name, opts| import_annotation(name, opts) }
    end    
    
    # Determines this annotated class's {#entity_id} and {#de_integration_proxy_class}.
    def initialize_annotation_holder
      @entity_id = Annotation::EntityFacade.instance.hook_entity_id(self)
    end
    
    # @param [Symbol] attribute the annotation accessor
    # @return [Module] the annotation module which implements the attribute
    def annotation_attribute_module(attribute)
      annotation_modules.detect { |mod| mod.proxy.attribute_defined?(attribute) }
    end

    # Builds a new annotation module for the given module name and options.
    #
    # @param [String] name the attribute module name
    # @param opts (see #add_annotation)
    # @return [Module] the annotation module
    # @raise [AnnotationError] if there is no annotation proxy class
    def import_annotation(name, opts)
      logger.debug { "Importing #{qp} annotation #{name}..." }
      # Make the annotation module scoped by this Annotatable class.
      class_eval("class #{name}; end")
      klass = const_get(name)
      # Append the AnnotationModule methods.
      AnnotationModule.extend_module(klass, self, opts)
      # Make the proxy attribute.
      attr = create_proxy_attribute(klass)
      # The proxy is a logical dependent.
      add_dependent_attribute(attr, :logical)
      logger.debug { "Created #{qp} annotation proxy logical dependent reference attribute #{attr}." }
      # Fill out the dependency hierarchy.
      klass.proxy.build_annotation_dependency_hierarchy
      klass
    end

    # Returns whether this class has an annotation whose proxy accessor is the
    # given symbol.
    #
    # @param (see #annotation?)
    # @return (see #annotation?)
    # @see #annotation?
    def annotation_defined?(symbol)
      attribute_defined?(symbol) and attribute_metadata(symbol).type < Annotation
    end
    
    # Makes an attribute whose name is the demodulized underscored given module name.
    # The attribute reader creates an {Annotation::Proxy} instance of the method
    # receiver {Annotatable} instance on demand.
    # 
    # @param [AnnotationModule] klass the subject annotation
    # @return [Symbol] the proxy attribute
    def create_proxy_attribute(klass)
      # the proxy class
      pxy = klass.proxy
      # the proxy attribute symbol
      attr = klass.name.demodulize.underscore.to_sym
      # Define the proxy attribute.
      attr_create_on_demand_accessor(attr) { Set.new }
      # Register the attribute.
      add_attribute(attr, pxy, :collection, :saved)
      logger.debug { "Added #{qp} #{klass.qp} annotation proxy attribute #{attr} of type #{pxy}." }
      # the annotation module => proxy attribute association
      @ann_mod_pxy_hash[klass] = attr
      attr
    end
  end
end
