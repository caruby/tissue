require 'catissue/annotation/annotation'
require 'catissue/database/annotation/reference_writer'

module CaTissue
  module AnnotationClass
    
    # @return [Symbol, nil] the annotation => proxy attribute, or nil if this is not a primary annotation
    attr_reader :proxy_attribute_metadata
    
    # @return [Integer, nil] the annotation class designator that is used by caTissue to persist primary
    #   annotation objects, or nil if this is not a primary annotation
    attr_reader :entity_id
    
    # @return [Intger, nil] the container id, or nil if this is not a primary annotation
    attr_reader :container_id
    
    def self.extend_class(klass, mod)
      # Enable the class meta-data.
      klass.extend(CaRuby::Domain::Metadata)
      # Extend with annotation meta-data.
      klass.extend(self).add_annotation_metadata(mod)
    end
    
    # @return [Module] the scoping annotation module
    def annotation_module
      domain_module
    end
    
    # Adds metadata to this annotation class.
    #
    # @param [Module] mod the annotation module
    def add_annotation_metadata(mod)
      alias_attribute(:annotation_module, :domain_module)
      efcd = Annotation::EntityFacade.instance
      @entity_id = efcd.annotation_entity_id(self, false)
      @is_primary = efcd.primary?(@entity_id) if @entity_id
      # A primary entity has a container id.
      if primary? then
        logger.debug { "Annotation #{self} is a primary top-level annotation." }
        @container_id = efcd.container_id(@entity_id)
      end
      pxy = mod.proxy || return
      attr_md = detect_proxy_attribute_metadata(pxy) || return
      pxy.set_proxy_attribute_metadata(attr_md)
    end

    # Filters {CaRuby::Domain::Attributes#loadable_attributes} to exclude all references,
    # since annotation lazy-loading is not supported.
    #
    # @return [Array] an empty array
    def loadable_attributes
      Array::EMPTY_ARRAY
    end
    
    # Saves the annotations referenced by the given annotation.
    #
    # @param [Annotation] annotation the subject annotation
    def save_dependent_attributes(annotation)
      dependent_attributes.each { |attr| save_dependent_attribute(annotation, attr) }
    end
    
    # @return [Boolean] whether this annotation refers to a {#primary?} annotation
    def secondary?
      ref = domain_attributes.detect_with_metadata { |attr_md| attr_md.type < Annotation and attr_md.type.primary? }
      not ref.nil?
    end
    
    # @return [Boolean] whether this annotation is neither a {#primary?} nor a #{secondary} annotation
    def tertiary_annotation
      not (primary? or secondary?)
    end
    
    # @return [ProxyClass] the annotation proxy class
    def proxy_class
      annotation_module.proxy
    end
    
    alias :proxy :proxy_class
    
    # @return [AnnotatableClass] the annotated domain object class
    def hook_class
      proxy.hook
    end
    
    alias :hook :hook_class
#    
#    # @param [Class] klass the hook class for this primary annotation
#    def hook=(klass)
#      # only a primary can have a hook
#      unless primary? then
#        raise AnnotationError.new("#{annotation_module.qp} annotation #{qp} #{annotation_module.proxy.qp} proxy owner accessor attribute not found.")
#      end
#      # redirect the hook writer method to write to the proxy instead
#      convert_hook_to_proxy(klass)
#    end
    
    # @return [Symbol, nil] the attribute which references the hook proxy,
    #   or nil if this is not a primary annotation class
    def proxy_attribute
      @pxy_attr_md.to_sym if @pxy_attr_md
    end
    
    # @return [Symbol, nil] the hook proxy class attribute which references this annotation class,
    #   or nil if this is not a primary annotation class
    def hook_proxy_attribute
      # The hook => primary attribute symbol is the same as the proxy => primary attribute symbol.
      @pxy_attr_md.inverse if @pxy_attr_md
    end
    
    # @return [Boolean] whether this annotation class references a hook proxy
    def primary?
      @is_primary
    end
    
    # @return [Array] an empty array, since no annotation reference is lazy-loaded by caTissue.
    def toxic_attributes
      Array::EMPTY_ARRAY
    end
    
    def proxy_attribute_metadata
      @pxy_attr_md
    end
    
    protected
    
    # @return [Symbol => ReferenceWriter] this class's attribute => writer hash
    def attribute_writer_hash
      @attr_writer_hash ||= map_writers
    end
    
    # Marks each of this annotation class's non-owner domain attributes as a dependent.
    def add_dependent_attributes
      # First infer the attribute inverses.
      infer_inverses
      # Select the annotation attributes to make dependent.
      attrs = domain_attributes.compose do |attr_md|
        attr_md != @pxy_attr_md and attr_md.type < Annotation and not (attr_md.dependent? or attr_md.owner?) and attr_md.declarer == self
      end
      # Copy the attributes to an array before iteration, since adding a dependent attribute
      # might also add another attribute in the case of a proxy.
      attrs.to_a.each do |attr|
        logger.debug { "Adding annotation #{qp} #{attr} attribute as a logical dependent..." }
        add_dependent_attribute(attr, :logical)
      end
    end
    
    # Infers this annotation class inverses attribute.
    # This method is called by the annotation module on each imported annotated class.
    def infer_inverses
      domain_attributes.each_metadata do |attr_md|
        if attr_md.inverse.nil? and attr_md.declarer == self then
          attr_md.declarer.infer_attribute_inverse(attr_md)
        end
      end
    end
    
    # Recurses the dependency hierarchy to this annotation class's dependents in a
    # breadth-first manner.
    #
    # @param [<CaRuby::Domain::Attribute>] path the visited attributes
    def add_dependent_attribute_closure(path=[])
      return if path.include?(self)
      attrs = dependent_attributes(false)
      return if attrs.empty?
      
      # recurse to dependents
      path.push(self)
      dependent_attributes(false).each_metadata do |attr_md|
        klass = attr_md.type
        klass.add_dependent_attribute_closure(path)
      end
      path.pop

      logger.debug { "Adding #{qp} dependents..." }
      # add breadth-first dependencies
      dependent_attributes(false).each_pair do |attr, attr_md|
        attr_md.type.add_dependent_attributes
      end
      logger.debug { "Added #{qp} dependents #{dependent_attributes(false).qp}." }
    end
    
    # Detects or creates the proxy attribute that references the given proxy class.
    # If this is a primary entity annotation class which does not
    # have a caTissue proxy property, then a new attribute is created.
    #
    # @param [Annotation::ProxyClass] klass the annotation module proxy class
    def define_proxy_attribute(klass)
      # must be primary
      unless primary? then raise AnnotationError.new("Can't set proxy for non-primary annotation class #{qp}") end
      # If the proxy is already set, then confirm that this call is redundant, which is allowed,
      # as opposed to conflicting, which is not allowed.
      if @pxy_attr_md then
        return if @pxy_attr_md.type == klass
        raise AnnotationError.new("Can't reset #{self} proxy from #{@pxy_attr_md.type} to #{klass}")
      end
      logger.debug { "Setting annotation #{qp} proxy to #{klass}..." }
      # the annotation => proxy reference attribute
      attr_md = obtain_proxy_attribute_metadata(klass)
      # caTissue 1.1.2 confusingly names the proxy the same as the hook; correct this.
      hook_attr = klass.hook.name.demodulize.underscore.to_sym
      if attr_md.to_sym == hook_attr then
        @pxy_attr_md = wrap_1_1_proxy_attribute(attr_md)
      else
        @pxy_attr_md = attr_md
        # Alias the attribute with the proxy hook name, e.g. the Clinical::AlcoholAnnotation -> ParticipantRecordEntry
        # proxy reference attribute participant_record_entry is aliased by clinical.
        aliaz = annotation_module.name.demodulize.underscore.to_sym
        alias_attribute(aliaz, attr_md.to_sym)
        # Make the hook attribute.
        define_method(hook_attr) { pxy = send(aliaz); pxy.hook if pxy }
        define_method("#{hook_attr}=".to_sym) { |obj| pxy = obj.send(aliaz) if obj; send(attr_md.writer, pxy) }
        add_attribute(hook_attr, klass.hook)
      end
      # Make the proxy alias to the proxy attribute.
      alias_attribute(:proxy, @pxy_attr_md.to_sym)
      # Make the hook alias to the hook attribute.
      alias_attribute(:hook, hook_attr)
    end
    
    private
    
    # Wraps the caTissue 1.1.x proxy attribute with a hook argument and return value.
    # If the superclass is a primary annotation, then this method delegates
    # to the superclass to set the proxy attribute. Otherwise, the proxy accessor
    # methods are modified as follows:
    # * the proxy writer converts a hook argument to its proxy
    # * the proxy reader converts a proxy to its hook
    # * the proxy is aliased as a hook attribute, if necessary, e.g.  +participant+
    #   is aliased to +participant_record_entry+
    #
    # @param [CaRuby::Domain::Attribute] attr_md the proxy attribute
    def wrap_1_1_proxy_attribute(attr_md)
      logger.debug { "Setting annotation #{qp} proxy to #{attr_md}..." }
      # If the superclass is also primary, then delegate to the superclass.
      sc = superclass
      if sc < Annotation and sc.primary? then
        sc.define_proxy_attribute(attr_md.type)
        @pxy_attr_md = sc.proxy_attribute_metadata
        return
      end
      
      logger.debug { "Setting #{qp} proxy class to #{attr_md.type.qp}..." }
      # Wrap the proxy attribute to read or write the hook instead of the proxy.
      # The annotation => proxy reference proxy attribute is set to the unwrapped proxy
      # accessor returned by the call.
      wrap_1_1_proxy(attr_md)
    end
    
    # Wraps the caTissue 1.1.x proxy owner attribute with a proxy <-> hook converter as follows:
    # * the reader method is redefined to convert a proxy to its hook
    # * the writer method is redefined to convert a hook argument to its proxy
    #
    # @param [CaRuby::Domain::Attribute] attr_md the proxy attribute
    # @return [CaRuby::Domain::Attribute] the original unwrapped attribute renamed to the underscore demodulized annotation module name
    def wrap_1_1_proxy(attr_md)
      if attr_md.nil? then
        raise AnnotationError.new("Cannot convert #{qp} => #{klass.qp} argument to a proxy since no proxy attribute is defined.")
      end
      logger.debug { "Adding #{qp} #{attr_md} attribute to wrap the proxy Java accessor methods with the hook JRuby accessor methods..." }
      # Wrap the proxy reader with a proxy => hook converter.
      convert_proxy_reader_result_to_hook(attr_md.reader)
      # the proxy => hook attribute metadata
      pxy_hook_attr_md = annotation_module.proxy.owner_attribute_metadata
      # the hook => proxy attribute
      hook_pxy_attr = pxy_hook_attr_md.inverse
      # Wrap the proxy writer with a hook -> proxy converter.
      convert_proxy_writer_hook_argument_to_proxy(attr_md.writer, hook_pxy_attr)
      # Reset the attribute type
      hook = pxy_hook_attr_md.type
      set_attribute_type(attr_md.to_sym, hook)
      logger.debug { "Reset #{qp} #{attr_md} type to the hook class #{hook}." }

      # Add the proxy reference attribute.
      pxy_attr = annotation_module.name.demodulize.underscore.to_sym
      pxy_attr_md = add_attribute(pxy_attr, annotation_module.proxy)
      logger.debug { "Added #{qp} => #{pxy_attr_md.type} proxy attribute #{pxy_attr_md}." }
      pxy_attr_md
    end
    
    def obtain_proxy_attribute_metadata(klass)
      attr_md = detect_proxy_attribute_metadata(klass) || create_proxy_attribute(klass)
      if attr_md.nil? then raise AnnotationError.new("Annotation #{qp} proxy attribute could not be found or created") end
      logger.debug { "Annotation class #{qp} has proxy reference attribute #{attr_md}." }
      attr_md
    end
    
    # Recursively saves the annotation dependency hierarchy rooted at the given annotation attribute.
    #
    # @param annotation (see #save_annotation)
    # @param [Symbol] attribute the attribute to save
    def save_dependent_attribute(annotation, attribute)
      annotation.send(attribute).enumerate do |ref|
        logger.debug { "Saving #{annotation} #{attribute} dependent #{ref.qp}..." }
        wtr = writer(attribute)
        if wtr.nil? then raise AnnotationError.new("Annotation reference writer not found for #{qp} #{attribute}") end
        wtr.save(ref)
        ref.class.save_dependent_attributes(ref)
      end
    end
    
    # @param [Symbol] attribute the annotation attribute
    # @return [AnnotationWriter] the attribute writer for instances of this class
    def writer(attribute)
      attribute_writer_hash[attribute]
    end
    
    # @return [{Symbol => Annotation::ReferenceWriter}] the annotation attribute => writer hash
    def map_writers
      hash = {}
      dependent_attributes.each_pair do |attr, attr_md|
        # skip attributes defined in a superclass
        next unless attr_md.declarer == self
        if @entity_id.nil? then
          raise AnnotationError.new("Cannot define reference writers for #{qp} since it does not have an entity id.")
        end
        hash[attr] = Annotation::ReferenceWriter.new(@entity_id, attr_md)
      end
      # If the superclass is also an annotation, then form the union of its writers with the local writers.
      superclass < Annotation && superclass.primary? ? hash + superclass.attribute_writer_hash : hash
    end
    
    # @param [ProxyClass] klass the proxy class
    # @return [CaRuby::Domain::Attribute] the annotation -> proxy attribute
    def detect_proxy_attribute_metadata(klass)
      domain_attributes.each_metadata { |attr_md| return attr_md if attr_md.type == klass }
      nil
    end
    
    # @param (see #proxy=)
    # @return [Symbol] the new annotation -> proxy attribute
    def create_proxy_attribute(klass)
      # the proxy attribute symbol
      attr = klass.hook.name.demodulize.underscore.to_sym
      logger.debug { "Creating primary annotation #{qp} proxy #{klass} attribute #{attr}..." }
      # make the attribute
      attr_accessor(attr)
      # Add the attribute. Setting the saved flag ensures that the save template passed to
      # the annotation service includes a reference to the hook object. This in turn allows
      # the annotation service to call the integration service to associate the annotation
      # to the hook object.
      add_attribute(attr, proxy, :saved)
      # make the inverse proxy -> annotation dependent attribute
      inverse = klass.create_annotation_attribute(self, attr)
      logger.debug { "Created primary annotation #{qp} proxy #{klass} attribute #{attr} with inverse #{inverse}." }
      
      attr
    end
    
    # Wraps the proxy reader method to convert a proxy to its hook.
    #
    # @param [Symbol] reader the proxy reader method
    def convert_proxy_reader_result_to_hook(reader)
      redefine_method(reader) do |old_mth|
        # Alias the proxy reader to the old method.
        alias_method(:proxy, old_mth)
        # Alias the annotation module attribute name to the old method.
        aliaz = annotation_module.name.demodulize.underscore.to_sym
        alias_method(aliaz, old_mth)
        # Convert the proxy to the hook.
        lambda do
          pxy = send(old_mth)
          pxy.hook if pxy
        end
      end
      logger.debug { "Redefined the #{qp} #{reader} reader method to convert a proxy parameter to its hook object." }
    end
    
    # Wraps the proxy writer method to convert a hook argument to its proxy.
    #
    # @param [Symbol] writer the proxy writer method
    # @param [Symbol] inverse the hook => proxy attribute
    def convert_proxy_writer_hook_argument_to_proxy(writer, inverse)
      klass = annotation_module.hook
      redefine_method(writer) do |old_mth|
        # Alias the proxy writer to the old method.
        alias_method(:proxy=, old_mth)
        # Alias the annotation module attribute name to the old method.
        aliaz = "#{annotation_module.name.demodulize.underscore}=".to_sym
        alias_method(aliaz, old_mth)
        lambda do |value|
          # Convert the parameter from a hook to a proxy, if necessary.
          pxy = klass === value ? value.send(inverse) : value
          unless pxy == value then logger.debug { "Converted #{qp} #{writer} argument from hook #{value.qp} to proxy #{pxy.qp}" } end
          send(old_mth, pxy)
        end
      end
      logger.debug { "Redefined the #{klass.qp} #{inverse} proxy writer #{writer} to convert a hook #{klass.qp} parameter to the hook proxy." }
    end
  end
end
