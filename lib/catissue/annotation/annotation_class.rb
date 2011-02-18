require 'xmlsimple'
require 'catissue/annotation/annotation'
require 'catissue/database/annotation/reference_writer'

module CaTissue
  module AnnotationClass
    
    # @return [Symbol, nil] the annotation => proxy attribute, or nil if this is not a primary annotation
    attr_reader :proxy_attribute
    
    # @return [Integer, nil] the annotation class designator that is used by caTissue to persist primary
    #   annotation objects, or nil if this is not a primary annotation
    attr_reader :entity_id
    
    # @return [Intger, nil] the container id, or nil if this is not a primary annotation
    attr_reader :container_id

    # Infers the given annotation class dependent attributes as described in
    # {#infer_dependents}.
    #
    # @param [Class] klass the annotation class
    def self.extended(klass)
      super
      klass.extend_as_annotation
    end
   
    # Adds metadata to this annotation class.
    def extend_as_annotation
      efcd = Annotation::EntityFacade.instance
      # The entity id, or nil if this is not a primary entity.
      @entity_id = efcd.primary_entity_id(self, false)
      # A primary entity has a container id.
      if @entity_id then @container_id = efcd.container_id(@entity_id) end
      # infer non-dependent attribute inverses
      detect_inverses
    end
    
    # Creates the proxy attribute if this is a primary_entity annotation class which does not
    # have a caTissue proxy property.
    #
    # @param [Class] proxy the {AnnotationProxy} class
    def ensure_primary_has_proxy(proxy)
      if primary? then @proxy_attribute ||= create_proxy_attribute(proxy) end
    end
    
    # Saves the annotations referenced by the given annotation.
    #
    # @param [Annotation] annotation the subject annotation
    def save_dependent_attributes(annotation)
      dependent_attributes.each { |attr| save_dependent_attribute(annotation, attr) }
    end
    
    # Detects or creates the proxy attribute that references the given proxy class.
    # if this is a primary_entity annotation class which does not
    # have a caTissue proxy property.
    #
    # @param [Class] proxy the {AnnotationProxy} class
    def proxy=(proxy)
      # msut be primary
      unless primary? then raise AnnotationError.new("Can't set proxy for non-primary annotation class #{qp}") end
      # make the proxy attribute
      @proxy_attribute = obtain_proxy_attribute(proxy)
      # set the hook
      self.hook = proxy.hook
      # primary superclass gets a proxy as well
      if superclass < Annotation and superclass.primary? then superclass.proxy = proxy end
    end
    
    # @param [Class] klass the hook class for this primary annotation
    def hook=(klass)
      # only a primary can have a hook
      unless primary? then
        raise AnnotationError.new("#{domain_module.qp} annotation #{qp} #{domain_module.proxy.qp} proxy owner accessor attribute not found.")
      end
      # redirect the hook writer method to write to the proxy instead
      convert_hook_to_proxy(klass)
    end
    
    # @return [Symbol, nil] the hook proxy class attribute which references this annotation, or nil if this
    #   class is not a primary annotation class
    def hook_proxy_attribute
      # The hook => primary attribute symbol is the same as the proxy => primary attribute symbol.
      attribute_metadata(@proxy_attribute).inverse if @proxy_attribute
    end
    
    # @return [Symbol, nil] the primary owner annotation, if it exists
    def primary_owner_attributes
      @pr_owr_attrs ||= domain_attributes.compose do |attr_md|
        attr_md.type < Annotation and attr_md.type.method_defined?(:hook)
      end
    end
    
    # @return [Boolean] whether this annotation class references a hook proxy
    def primary?
      not @entity_id.nil?
    end
    
    # @return [Array] an empty array, since no annotation reference is lazy-loaded by caTissue.
    def toxic_attributes
      Array::EMPTY_ARRAY
    end
    
    protected
    
    # @return [Symbol => ReferenceWriter] this class's attribute => writer hash
    def attribute_writer_hash
      @attr_writer_hash ||= map_writers
    end
        
    # Marks each of this annotation class's non-owner domain attributes as a dependent.
    def add_dependent_attributes
      domain_attributes.each_pair do |attr, attr_md|
        next if attr == @proxy_attribute or attr_md.dependent? or attr_md.owner? or not attr_md.declarer == self
        logger.debug { "Adding annotation #{qp} #{attr} attribute as a dependent..." }
        add_dependent_attribute(attr)
      end
    end
        
    # Recurses the dependency hierarchy to this annotation class's dependents in a
    # breadth-first manner.
    #
    # @param [<CaRuby::AttributeMetadata>] the visited attributes
    def add_dependent_attribute_closure(path=[])
      return if path.include?(self)
      attrs = dependent_attributes(false)
      return if attrs.empty?
      logger.debug { "Adding #{qp} dependents..." }
      # add breadth-first dependencies
      dependent_attributes(false).each_pair do |attr, attr_md|
        attr_md.type.add_dependent_attributes
      end
      # recurse to dependents
      dependent_attributes(false).each_metadata do |attr_md|
        klass = attr_md.type
        path.push(klass)
        klass.add_dependent_attribute_closure(path)
        path.pop
      end
      logger.debug { "Added #{qp} dependents #{dependent_attributes(false).qp}." }
    end
    
    private
    
    # Infers this annotation class inverses attributes. A domain attribute is
    # recognized as an inverse according to the {ResourceInverse#detect_inverse_attribute}
    # criterion. Annotation dependencies are not specified in a configuration and
    # follow the naming convention described in {ResourceInverse#detect_inverse_attribute}.
    def detect_inverses
      domain_attributes.each do |attr|
        attr_md = attribute_metadata(attr)
        next if attr_md.inverse
        inverse = attr_md.type.detect_inverse_attribute(self)
        if inverse then set_attribute_inverse(attr, inverse) end
      end
    end
    
    # Saves the annotations referenced by the given annotation attribute.
    #
    # @param annotation (see #save_annotation)
    # @param [Symbol] attribute the attribute to save
    def save_dependent_attribute(annotation, attribute)
      annotation.send(attribute).enumerate do |ref|
        logger.debug { "Saving #{annotation} #{attribute} dependent #{ref.qp}..." }
        writer(attribute).save(ref)
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
      cascaded_attributes.each_pair do |attr, attr_md|
        # skip attributes defined in a superclass
        next unless attr_md.declarer == self
        hash[attr] = Annotation::ReferenceWriter.new(@entity_id, attr_md)
      end
      # If the superclass is also an annotation, then form the union of its writers with the local writers.
      superclass < Annotation && superclass.primary? ? hash + superclass.attribute_writer_hash : hash
    end
    
    def obtain_proxy_attribute(proxy)
      # parent proxy is reserved for RadiationTherapy use case described in ParticipantTest.
      # TODO - either support this use case of delete the parent proxy call
      detect_proxy_attribute(proxy) or create_proxy_attribute(proxy) or parent_proxy_attribute
    end
    
    def parent_proxy_attribute
      superclass.proxy_attribute if superclass < Annotation
    end
    
    # @return [Symbol] the annotation -> proxy attribute
    def detect_proxy_attribute(proxy)
      attr_md = detect_proxy_attribute_metadata(proxy)
      if attr_md then
        attr_md.type = proxy.hook
        logger.debug { "Reset #{qp} #{attr_md} attribute type from the proxy class #{proxy} to the hook class #{proxy.hook}" }
      end
      attr_md
    end
    
    # @return [Symbol] the annotation -> proxy attribute
    def detect_proxy_attribute_metadata(proxy)
      domain_attributes.each_metadata { |attr_md| return attr_md if attr_md.type == proxy }
      nil
    end
    
    # @param [Class] proxy the domain module {Annotation::ProxyClass}
    # @return [Symbol] the new annotation -> proxy attribute
    def create_proxy_attribute(proxy)
      # the proxy attribute symbol
      attr = proxy.name.demodulize.underscore.to_sym
      logger.debug { "Creating primary annotation #{qp} proxy attribute #{attr}..." }
      # make the attribute
      attr_accessor(attr)
      # Add the attribute. Setting the saved flag ensures that the save template passed to
      # the annotation service includes a reference to the hook object. This in turn allows
      # the annotation service to call the integration service to associate the annotation
      # to the hook object.
      add_attribute(attr, proxy.hook, :saved)
      # make the inverse proxy -> annotation dependent attribute
      proxy.create_annotation_attribute(self, attr)
      attr
    end
    
    # Wraps the proxy owner attribute with a proxy <-> hook converter as follows:
    # * the reader method is redefined to convert a proxy to its hook
    # * the writer method is redefined to convert a hook argument to its proxy
    #
    # @param [Class] klass the hook class
    def convert_hook_to_proxy(klass)
      # the proxy reference attribute
      attr_md = attribute_metadata(@proxy_attribute)
      # wrap the proxy reader with a proxy => hook converter
      convert_proxy_reader_result_to_hook(attr_md.reader)
      # the proxy => hook attribute metadata
      pxy_hook_attr_md = domain_module.proxy.attribute_metadata(:hook)
      # the hook => proxy attribute
      hook_pxy_attr = pxy_hook_attr_md.inverse
      # wrap the proxy writer with a hook -> proxy converter
      convert_proxy_writer_hook_argument_to_proxy(attr_md.writer, klass, hook_pxy_attr)
    end
    
    # Wraps the proxy reader method to convert a proxy to its hook.
    #
    # @param [Symbol] reader the proxy reader method
    def convert_proxy_reader_result_to_hook(reader)
      redefine_method(reader) do |old_mth|
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
    # @param klass (see #convert_hook_to_proxy)
    # @param [Symbol] inverse the hook => proxy attribute
    def convert_proxy_writer_hook_argument_to_proxy(writer, klass, inverse)
      redefine_method(writer) do |old_mth|
        lambda do |value|
          # Convert the parameter from a hook to a proxy, if necessary.
          pxy = klass === value ? value.send(inverse) : value
          send(old_mth, pxy)
        end
      end
      logger.debug { "Redefined the #{klass.qp} #{inverse} proxy writer #{writer} to convert a hook #{klass.qp} parameter to the hook proxy." }
    end
  end
end
