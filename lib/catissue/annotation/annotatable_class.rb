require 'forwardable'
require 'caruby/util/inflector'
require 'catissue/annotation/annotation_module'

module CaTissue
  # Mix-in for extending a caTissue domain class with annotations.
  module AnnotatableClass
    
    # @return [Integer, nil] the the hook class designator that is used by caTissue to persist primary
    #   annotation objects, or nil if this is not a primary annotation class
    attr_reader :entity_id
    
    def self.extended(klass)
      super
      # the annotation name => spec hash 
      klass.class_eval do
        extend Forwardable
        @ann_spec_hash = {}
        @local_ann_attrs = []
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
   
    # If there is an existing annotation whose proxy accessor is the
    # given symbol, then return true. Otherwise, attempt to import
    # an annotation and return whether the import was successful.
    #
    # @param [Symbol] symbol the potential accessor attribute
    # @return [Boolean] whether there is a corresponding annotation
    def annotation_attribute?(symbol)
      # load annotations if necessary
      ensure_annotations_loaded
      # check for the annotation attribute
      annotation_defined?(symbol)
    end

    # Refines the {CaRuby::ResourceAttributes#toxic_attributes} to exclude annotation attributes.
    #
    # @return [<Symbol>] the non-annotation unfetched attributes
    def toxic_attributes
      @anntbl_toxic_attrs ||= unfetched_attributes.compose { |attr_md| not attr_md.type < Annotation } 
    end
    
    def annotation_proxy_attribute(attribute)
      annotatable_class_hierarchy.detect_value { |klass| klass.local_annotation_proxy_attribute(attribute) }
    end

    # Makes a new attribute in this hook class for the given annotation proxy domain attribute.
    # The hook annotation reference attribute delegates to the proxy. This method is intended for
    # the exclusive use of {Annotation::ProxyClass}.
    #
    # @param [AnnotationModule] mod the annotation module
    # @param [Symbol] attribute the proxy => annotation reference 
    def create_annotation_attribute(mod, attribute)
      pxy = mod.proxy
      pxy_attr = @ann_mod_pxy_hash[mod]
      ann_attr_md = pxy.attribute_metadata(attribute)
      # the type referenced by the annotation proxy
      klass = ann_attr_md.type
      # create annotation accessors which delegate to the proxy
      def_delegators(pxy_attr, *ann_attr_md.accessors)
      logger.debug { "Created #{qp}.#{attribute} which delegates to the annotation proxy #{pxy_attr}." }
      # add the attribute
      add_annotation_attribute(attribute, klass)
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
      @ann_attrs ||= append_ancestor_enum(@local_ann_attrs) do |sc|
        sc.annotation_attributes if sc < Annotatable
      end
    end
    
    protected
    
    # @return [<AnnotationModule>] the annotation modules in the class hierarchy
    def annotation_modules
      @ann_mods ||= load_annotations
    end
    
    # @param [Symbol] attribute the annotation attribute
    # @return [Symbol] the annotation proxy attribute
    # @raise [TypeError] if the given attribute is not an annotation attribute
    def local_annotation_proxy_attribute(attribute)
      unless annotation_attribute?(attribute) then
        raise TypeError.new("#{qp} #{attribute} is not an annotation attribute")
      end
      # the annotation class
      klass = attribute_metadata(attribute).type
      mod = klass.domain_module
      @ann_mod_pxy_hash[mod]
    end    
    
    private
    
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
      # the annotation module => proxy hash
      @ann_mod_pxy_hash = {}
      # an annotated class has a hook entity id
      unless @ann_spec_hash.empty? then
        @entity_id = Annotation::EntityFacade.instance.hook_entity_id(self) 
      end
      # build the annotations
      @ann_spec_hash.map { |name, opts| import_annotation(name, opts) }
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
      # make the annotation module scoped by this Annotatable class
      class_eval("module #{name}; end")
      mod = const_get(name)
      # append the AnnotationModule methods
      AnnotationModule.extend_module(mod, self, opts)
      # make the proxy attribute
      create_proxy_attribute(mod)
      # make the annotation dependent attributes
      create_annotation_attributes(mod)
      # add proxy references
      mod.ensure_proxy_attributes_are_defined
      mod.add_annotation_dependents
      logger.debug { "Imported #{qp} annotation #{name}." }
      mod
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
    # @param [AnnotationModule] mod the subject annotation module
    # @return [Symbol] the proxy attribute
    def create_proxy_attribute(mod)
      # the proxy class
      pxy = mod.proxy
      # the proxy attribute
      attr = mod.name.demodulize.underscore.to_sym
      # define the proxy attribute
      attr_create_on_demand_accessor(attr) { |obj| obj.create_proxy(pxy) }
      # add it as a standard (but unpersisted) attribute
      add_attribute(attr, pxy, :unsaved)
      # create the proxy => hook inverse
      pxy.set_hook(self, attr)
      logger.debug { "Added #{qp} #{mod.qp} annotation proxy attribute #{attr}." }
      # the annotation module => proxy attribute association
      @ann_mod_pxy_hash[mod] = attr
      attr
    end

    # Makes a new attribute in this hook class for each of the given annotation module's
    # proxy domain attributes. The hook annotation reference attribute delegates to the
    # proxy.
    #
    # @param [AnnotationModule] mod the subject annotation module
    # @param [Symbol] proxy_attribute the hook => proxy reference 
    def create_annotation_attributes(mod)
      # create annotation attributes which delegate to the proxy
      mod.proxy.annotation_attributes.each do |attr|
        create_annotation_attribute(mod, attr)
      end
    end

    # Adds the given annotation attribute as a dependent collection attribute with meta-data.
    #
    # @param [Symbol] attribute the annotation accessor
    # @param [Class] type the attribute domain type
    def add_annotation_attribute(attribute, type)
      logger.debug { "Adding #{qp} #{type.qp} annotation attribute #{attribute}..." }
      # Mark the attribute as a collection.
      add_attribute(attribute, type, :collection)
      
      # the camel-case attribute is a potential alias
      jattr = attribute.to_s.camelize(:lower).to_sym
      unless attribute == jattr then
        add_attribute_aliases(jattr => attribute)
      end
      
      # the annotation is a dependent
      add_dependent_attribute(attribute, :logical)
      # add the attribute to the local collection
      @local_ann_attrs << attribute
      
      attribute
    end
  end
end
