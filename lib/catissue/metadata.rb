require 'caruby/metadata'
require 'catissue/annotation/importer'
require 'catissue/annotation/importer_1_2'
require 'catissue/annotation/integration_1_2'

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
    
    # @quirk caTissue 2.0 Prior to caTissue 2.0, DEs had two proxy classes, a domain proxy class and
    #   a DE proxy class, e.g. the domain proxy class
    #   +edu.wustl.catissuecore.domain.deintegration.ParticipantRecordEntry+ and the DE proxy class
    #   +clinical.ParticipantRecordEntry+. caTissue 2.0 retains the domain DE proxy class but
    #   eliminates the DE proxy class. caRuby worked around caTissue 1.1.2 DE bugs by maintaining
    #   the intricate DE proxy machinery in special-purpose code. This is no longer necessary in
    #   2.0.
    # 
    # @return [Class] the {Annotation::DEIntegration} proxy class (nil for 1.1 caTissue)
    def de_integration_proxy_type
      @dei_pxy_class or (superclass.de_integration_proxy_type if superclass < Annotatable)
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

    # Filters +CaRuby::Propertied#loadable_attributes} to exclude the {#annotation_attributes}
    # since annotation lazy-loading is not supported.
    #
    # @quirk JRuby - Copied +CaRuby::Persistable#loadable_attributes+ to avoid infinite loop.
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
    
    def proxy_property_for(mod)
      @pxy_prop ||= {}
      @pxy_prop[mod] ||= obtain_proxy_property(mod)
    end      

    # Returns the hook -> proxy property for the given annotation module and proxy class.
    # A default attribute is created, if necessary, whose name is the demodulized,
    # underscored given module name.
    #
    # @quirk caTissue 2.0 caTissue 2.0 save cascades from a hook to the DE RecordEntry.
    #   Previous releases ignored each referenced DE RecordEntry. 
    # 
    # @param [AnnotationModule] mod the subject annotation
    # @param [Class] proxy the proxy type
    # @return [Jinx::Property] the proxy reference property
    def obtain_proxy_property(mod)
      prop = properties.detect { |p| p.type == mod.proxy }
      prop ||= create_proxy_attribute(mod)
      pa = prop.attribute
      # Alias the proxy by the module name, if necessary.
      aliaz = mod.name.demodulize.underscore.to_sym
      alias_attribute(aliaz, pa) unless pa == aliaz
      # the annotation module => proxy attribute association
      @ann_mod_pxy_hash ||= {}
      @ann_mod_pxy_hash[mod] = pa
      # The caTissue 1.2 proxy is a logical dependent.
      prop.qualify(:logical) unless CaTissue::Database.current.uniform_application_service?
      logger.debug { "Added the #{qp} => #{mod.qp}::#{mod.proxy.qp} annotation proxy reference dependent attribute #{pa}." }
      pa
    end

    # Sets the pre-2.0 proxy class to the {Annotation::DEIntegration#proxy} with the given name.
    #
    # @param [String] name the proxy record entry class name
    def obtain_pre_2_0_proxy_type(name)
      @dei_pxy_class = Annotation::Integration_1_2.const_get(name) rescue nil
      if @dei_pxy_class then
        logger.debug { "The pre-2.0 #{qp} proxy class is #{name}." }
      else
        logger.debug { "The pre-2.0 #{qp} proxy class #{name} is unsupported in this caTissue release." }
      end
      name
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
    # @option opts [<String>, String] :packages the package names (default is the lower-case underscore *name*)
    # @option opts [String] :service the pre-caTissue 2.0 service name (default is the lower-case underscore *name*)
    # @option opts [String] :group the DE group short name (default is the package)
    # @option opts [String] :proxy_name the DE proxy class name (default is the class name followed by +RecordEntry+)
    def add_annotation(name, opts={})
      # the module symbol
      mod_sym = name.camelize.to_sym
      # the module spec defaults
      pkgs = opts[:packages] ||= name.underscore
      grp = opts[:group] ||= Array === pkgs ? pkgs.first : pkgs
      unless CaTissue::Database.current.uniform_application_service? then
        pxy_nm = opts[:proxy_name] || "#{self.name.demodulize}RecordEntry"
        self.obtain_pre_2_0_proxy_type(pxy_nm)
      end
      # add the annotation entry
      @ann_spec_hash ||= {}
      @ann_spec_hash[mod_sym] = opts
      logger.info("Added #{qp} annotation #{name} with the following characteristics:\n  #{opts.pp_s}")
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
  
    # Determines this annotated class's {#entity_id}.
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
      mod.extend(importer_module)
      # Build the annnotation module.
      mod.initialize_annotation(self, opts)
      # Initialize the proxy property and alias on demand.
      pxy_prop = proxy_property_for(mod)
      logger.debug { "Imported #{qp} annotation #{name} with proxy reference #{pxy_prop}." }
      mod
    end
    
    # @return [Module] {Importer} if this is caTissue 2.0 or later, {Importer_1_2} otherwise
    def importer_module
      CaTissue::Database.current.uniform_application_service? ? Annotation::Importer : Annotation::Importer_1_2
    end

    # Makes an attribute whose name is the demodulized underscored given module name.
    # The attribute reader creates an {Annotation::Proxy} instance of the method
    # receiver {Annotatable} instance on demand.
    # 
    # @param [AnnotationModule] mod the subject annotation
    # @return [ProxyClass] proxy the proxy class
    def create_proxy_attribute(mod)
      # the proxy attribute symbol
      pa = mod.name.demodulize.underscore.to_sym
      # Define the proxy attribute.
      attr_create_on_demand_accessor(pa) { Set.new }
      # Register the attribute.
      prop = add_attribute(pa, mod.proxy, :collection, :saved, :nosync)
      add_dependent_property(prop)
      logger.debug { "Created the #{qp} => #{mod.proxy} #{mod.qp} annotation proxy dependent reference attribute #{pa}." }
      prop
    end
  end
end
