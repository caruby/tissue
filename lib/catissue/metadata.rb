require 'caruby/metadata'
require 'catissue/annotation/importer'
require 'catissue/annotation/de_integration'

module CaTissue
  # Mix-in for extending a caTissue domain class with +Jinx::Metadata+ introspection and annotations.
  module Metadata
    include CaRuby::Metadata
    
    # @return [Integer, nil] the the hook class designator that is used by caTissue to persist primary
    #   annotation objects, or nil if this is not a primary annotation class
    attr_reader :entity_id

    # Declares that the given {Annotation} classes will be dynamically modified.
    # This method introspects the classes, if necessary.
    #
    # @param [<Class>] classes the classes to modify
    def shims(*classes)
      # Nothing to do, since all this method does is ensure that the arguments are
      # introspected when they are referenced.
    end
    
    # @return [Class] the {Annotation::DEIntegration} proxy class (nil for 1.1 caTissue)
    def de_integration_proxy_class
      @de_integration_proxy_class or (superclass.de_integration_proxy_class if superclass < Annotatable)
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

    # Refines the +CaRuby::Propertied.toxic_attributes+ to exclude annotation attributes.
    #
    # @return [<Symbol>] the non-annotation unfetched attributes
    def toxic_attributes
      @anbl_toxic_attrs ||= unfetched_attributes.compose { |prop| not prop.type < Annotation } 
    end

    # @param [AnnotationModule] mod the annotation module
    # @return [Symbol] the corresponding annotation proxy reference attribute
    def annotation_proxy_attribute(mod)
      (@ann_mod_pxy_hash and @ann_mod_pxy_hash[mod]) or
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

    # Filters +CaRuby::Propertied#loadable_attributes} to exclude the {.annotation_attributes+
    # since annotation lazy-loading is not supported.
    #
    # @quirk JRuby - Copied {CaRuby::Persistable#loadable_attributes} to avoid infinite loop.
    #
    # @see #const_missing
    # @return (see CaRuby::Propertied#loadable_attributes)
    def loadable_attributes
      @antbl_ld_attrs ||= unfetched_attributes.compose do |prop|
        # JRuby bug - Copied the super body to avoid infinite loop.
        prop.java_property? and not prop.type.abstract? and not prop.transient? and not prop.type < Annotation
      end
    end
  
    def printable_attributes
      # JRuby bug - Copied super body to avoid infinite loop. See const_missing.
      @prbl_attrs ||= java_attributes.union(annotation_attributes)
    end
  
    def annotation_attributes
      @ann_mod_pxy_hash ||= {}
      @ann_attrs ||= append_ancestor_enum(@ann_mod_pxy_hash.enum_values) do |sc|
        sc.annotation_attributes if sc < Annotatable
      end
    end
                         
    # @param [String] a class name, optionally qualified by the annotation module
    # @return [Class, nil] the annotation class with the given name,
    #   or nil if no such annotation is found
    # @raise [NameError] if there is more than one annotation class for the given name
    def annotation_class_for_name(name)
      nmod = name[/^\w+/] if name.index('::')
      klasses = annotation_modules.map do |mod|
        cnm = nmod && mod.name.demodulize == (nmod) ? name[nmod.length..-1] : name
        mod.module_for_name(cnm) rescue nil
      end
      klasses.compact!
      if klasses.size > 1 then
        raise NameError.new("Ambiguous #{self} annotation classes for #{name}: #{klasses.to_series}")
      end
      klasses.first
    end
  
    protected
  
    # @return [<AnnotationModule>] the annotation modules in the class hierarchy
    def annotation_modules
      @ann_mods ||= load_annotations
    end
  
    private
  
    # @return [Boolean] whenter this class's annotations are loaded
    def annotations_loaded?
      !!@ann_mods
    end
  
    # @param [String] name the proxy record entry class name
    def annotation_proxy_class_name=(name)
      @de_integration_proxy_class = Annotation::DEIntegration.proxy(name)
      if @de_integration_proxy_class then
        # hide the internal caTissue proxy collection attribute
        pa = domain_attributes.detect_attribute_with_property { |prop| prop.type <= @de_integration_proxy_class }
        if pa then
          remove_attribute(pa)
          logger.debug { "Hid the internal caTissue #{qp} annotation record-keeping attribute #{pa}." }
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
    # @option opts [String] :package the package name (default is the lower-case underscore name)
    # @option opts [String] :service the service name (default is the lower-case underscore name)
    # @option opts [String] :group the DE group short name (default is the package)
    # @option opts [String] :proxy_name the DE proxy class name (default is the class name followed by +RecordEntry+)
    def add_annotation(name, opts={})
      # the module symbol
      mod_sym = name.camelize.to_sym
      # the module spec defaults
      pkg = opts[:package] ||= name.underscore
      svc = opts[:service] ||= name.underscore
      grp = opts[:group] ||= pkg
      pxy_nm = opts[:proxy_name] || "#{self.name.demodulize}RecordEntry"
      self.annotation_proxy_class_name = pxy_nm
      # add the annotation entry
      @ann_spec_hash ||= {}
      @ann_spec_hash[mod_sym] = opts
      logger.info("Added #{qp} annotation #{name} with module #{mod_sym}, package #{pkg}, service #{svc} and group #{grp}.")
    end
  
    # @return [Boolean] whether this annotatable class's annotations are loaded
    def annotations_loaded?
      !!@ann_mods
    end
  
    # Loads this class's annotations.
    #
    # @return [<AnnotationModule>] the loaded annotation modules
    def load_local_annotations
      return Array::EMPTY_ARRAY if @ann_spec_hash.nil?
      # an annotated class has a hook entity id
      initialize_annotation_holder
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
      annotation_modules.detect { |mod| mod.proxy.property_defined?(attribute) }
    end

    # Builds a new annotation module for the given module name and options.
    #
    # @param [String] name the attribute module name
    # @param opts (see #add_annotation)
    # @return [Module] the annotation module
    # @raise [AnnotationError] if there is no annotation proxy class
    def import_annotation(name, opts)
      logger.debug { "Importing #{qp} annotation #{name}..." }
      # Make the annotation module class scoped by this Annotatable class.
      class_eval("module #{name}; end")
      mod = const_get(name)
      # Append the AnnotationModule methods.
      mod.extend(Annotation::Importer)
      # Build the annnotation module.
      mod.initialize_annotation(self, opts) { |pxy| create_proxy_attribute(mod, pxy) }
      mod
    end

    # Returns whether this class has an annotation whose proxy accessor is the
    # given symbol.
    #
    # @param (see #annotation?)
    # @return (see #annotation?)
    # @see #annotation?
    def annotation_defined?(symbol)
      property_defined?(symbol) and property(symbol).type < Annotation
    end
  
    # Makes an attribute whose name is the demodulized underscored given module name.
    # The attribute reader creates an {Annotation::Proxy} instance of the method
    # receiver {Annotatable} instance on demand.
    # 
    # @param [AnnotationModule] mod the subject annotation
    # @return [ProxyClass] proxy the proxy class
    def create_proxy_attribute(mod, proxy)
      # the proxy attribute symbol
      pa = mod.name.demodulize.underscore.to_sym
      # Define the proxy attribute.
      attr_create_on_demand_accessor(pa) { Set.new }
      # Register the attribute.
      add_attribute(pa, proxy, :collection, :saved, :nosync)
      # the annotation module => proxy attribute association
      @ann_mod_pxy_hash ||= {}
      @ann_mod_pxy_hash[mod] = pa
      # The proxy is a logical dependent.
      add_dependent_attribute(pa, :logical)
      logger.debug { "Created #{qp} #{mod.qp} annotation proxy logical dependent reference attribute #{pa} to #{proxy}." }
      pa
    end
  end
end
