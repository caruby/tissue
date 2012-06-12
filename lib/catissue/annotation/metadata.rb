require 'catissue/annotation/annotation'
require 'catissue/annotation/introspector'
require 'catissue/database/annotation/reference_writer'

module CaTissue
  module Annotation
    module Metadata
      include CaRuby::Metadata
  
      # @return [Integer, nil] the annotation class designator that is used by caTissue to persist primary
      #   annotation objects, or nil if this is not a primary annotation
      attr_reader :entity_id
  
      # @return [Intger, nil] the container id, or nil if this is not a primary annotation
      attr_reader :container_id

      # @return [Module] the module which imported this annotation class 
      attr_reader :annotation_module
  
      # @return [<Class>] the annotation class hierarchy, including this class
      def annotation_hierarchy
        class_hierarchy.filter { |klass| klass < Annotation }
      end
  
      # @return [Boolean] whether this annotation class references a hook proxy
      def primary?
        @is_primary
      end
  
      # @return [Boolean] whether this annotation refers to a {#primary?} annotation
      def secondary?
        ref = domain_attributes.detect_with_metadata { |prop| prop.type < Annotation and prop.type.primary? }
        not ref.nil?
      end
  
      # @return [Boolean] whether this annotation is neither a {#primary?} nor a {#secondary?} annotation
      def tertiary?
        not (primary? or secondary?)
      end

      # Adds metadata to this annotation class.
      # This method is intended for the sole use of the Annotation {Importer}.
      #
      # @param [Module] mod the module which scopes this annotation 
      def add_annotation_metadata(mod)
        logger.debug { "Adding #{mod.qp} annotation #{qp} metadata..." }
        # Set the primary key.
        property :identifier, :primary_key
        self.annotation_module = mod
        infer_entity_id
        logger.debug { "#{mod.qp} annotation #{qp} metadata is complete." }
      end
  
      # @return [Symbol] the domain attributes which include {Annotation}
      def annotation_attributes
        @ann_attrs ||= domain_attributes.compose { |prop| prop.type < Annotation }
      end

      # Filters +CaRuby::Propertied.loadable_attributes+ to exclude all references,
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
        dependent_attributes.each { |pa| save_dependent_attribute(annotation, pa) }
      end
  
      # @return [ProxyClass] the annotation proxy class
      def proxy_class
        annotation_module.proxy
      end
  
      alias :proxy :proxy_class
  
      # @return [Metadata] the annotated domain object class
      def hook_class
        proxy.hook
      end
  
      alias :hook :hook_class
  
      # @return [Jinx::Property, nil] the attribute metadata which references
      #   the hook proxy, or nil if this is not a primary annotation class
      def proxy_property
        @pxy_prop
      end
  
      # @return [Symbol, nil] the attribute symbol which references the hook proxy,
      #   or nil if this is not a primary annotation class
      def proxy_attribute
        @pxy_prop.to_sym if @pxy_prop
      end
  
      # @return [Symbol, nil] the hook proxy class attribute which references this annotation class,
      #   or nil if this is not a primary annotation class
      def hook_proxy_attribute
        # The hook => primary attribute symbol is the same as the proxy => primary attribute symbol.
        @pxy_prop.inverse if @pxy_prop
      end
  
      # @return [Array] an empty array, since no annotation reference is lazy-loaded by caTissue.
      def toxic_attributes
        Array::EMPTY_ARRAY
      end
  
      protected
      
      # Sets this {Annotation} class's scoping module. If this class's superclass is also an
      # {Annotation}, then the superclass annotation module is set as well. The superclass
      # annotation module must be set before this class's entity id is inferred.
      #
      # @param [Module] mod the module which scopes this annotation 
      def annotation_module=(mod)
        superclass.annotation_module ||= mod if superclass < Annotation
        @annotation_module = mod
      end
  
      # @return [Symbol => ReferenceWriter] this class's attribute => writer hash
      def attribute_writer_hash
        @attr_writer_hash ||= map_writers
      end
  
      # Marks each of this annotation class's non-owner domain attributes as a dependent.
      def add_dependent_attributes
        # First infer the attribute inverses.
        infer_inverses
        # Select the annotation attributes to make dependent.
        pa = domain_attributes.compose do |prop|
          prop != @pxy_prop and prop.type < Annotation and not (prop.dependent? or prop.owner?) and prop.declarer == self
        end
        # Copy the attributes to an array before iteration, since adding a dependent attribute
        # might also add another attribute in the case of a proxy.
        pa.to_a.each do |pa|
          logger.debug { "Adding annotation #{qp} #{pa} attribute as a logical dependent..." }
          add_dependent_attribute(pa, :logical, :unsaved)
        end
      end
  
      # Infers this annotation class inverses attribute.
      # This method is called by the annotation module on each imported annotated class.
      def infer_inverses
        annotation_attributes.each_property do |prop|
          if prop.inverse.nil? and prop.declarer == self then
            prop.declarer.infer_property_inverse(prop)
          end
        end
      end
  
      # Recurses the dependency hierarchy to this annotation class's dependents in a
      # breadth-first manner.
      #
      # @param [<Jinx::Property>] path the visited attributes
      def add_dependent_attribute_closure(path=[])
        return if path.include?(self)

        # add breadth-first dependencies
        deps = dependent_attributes(false)
        return if deps.empty?
        logger.debug { "Adding #{qp} annotation dependents #{deps.qp}..." }
        deps.each_property { |prop| prop.type.add_dependent_attributes }
        logger.debug { "Added #{qp} dependents #{deps.qp}." }
    
        # recurse to dependents
        path.push(self)
        dependent_attributes(false).each_property do |prop|
          klass = prop.type
          klass.add_dependent_attribute_closure(path)
        end
        path.pop
      end
  
      # Creates the proxy attribute that references the given proxy class, if it is not
      # already defined.
      #
      # @param [Annotation::ProxyClass] klass the annotation module proxy class
      # @raise [AnnotationError] if this annotation is not {#primary?}
      # @raise [AnnotationError] if the proxy attribute is already set and references a
      #   different proxy class
      def define_proxy_attribute(klass)
        # Only a primary annotation class can have a proxy.
        unless primary? then
          raise AnnotationError.new("Can't set proxy for non-primary annotation class #{qp}")
        end
        # If the proxy is already set, then confirm that this call is redundant, which is tolerated
        # as a no-op, as opposed to conflicting, which is not allowed.
        if @pxy_prop then
          return if @pxy_prop.type == klass
          raise AnnotationError.new("Can't reset #{self} proxy from #{@pxy_prop.type} to #{klass}")
        end
        logger.debug { "Setting annotation #{qp} proxy to #{klass}..." }
        # the annotation => proxy reference attribute
        prop = obtain_proxy_property(klass)
        # The canonical proxy attribute is named after the annotation module, e.g. clinical.
        # caTissue 1.1.x confusingly names the proxy the same as the hook. Correct this by repurposing
        # the proxy as the hook attribute and making a separate proxy attribute named by the annotation
        # module.
        hook_attr = klass.hook.name.demodulize.underscore.to_sym
        if prop.to_sym == hook_attr then
          wrap_1_1_proxy_attribute(prop)
        else
          set_proxy_property(prop, hook_attr)
        end
        logger.debug { "Annotation #{qp} proxy reference attribute is #{@pxy_prop}." }
    
        # Alias 'proxy' to the proxy attribute.
        logger.debug { "Aliased annotation #{qp} :proxy to #{@pxy_prop}." }
        alias_attribute(:proxy, @pxy_prop.to_sym)
        # Alias 'hook' to the hook attribute.
        logger.debug { "Aliased annotation #{qp} :hook to #{hook_attr}." }
        alias_attribute(:hook, hook_attr)
      end
  
      private

      # Determines this annotation's entity id. 
      def infer_entity_id
        # The entity facade determines various caTissue DE arcana, including the entity id,
        # primary status and the container id.
        efcd = Annotation::EntityFacade.instance
        @entity_id = efcd.annotation_entity_id(self, false)
        @is_primary = efcd.primary?(@entity_id) if @entity_id
        # A primary entity has a container id.
        if primary? then
          @container_id = efcd.container_id(@entity_id)
          if @container_id.nil? then
            raise AnnotationError.new("Primary annotation #{self} is missing a container id")
          end
          logger.debug { "Primary annotation #{self} has container id #{@container_id}." }
          pxy = @annotation_module.proxy
          pxy.ensure_primary_references_proxy(self) if pxy
        end
        logger.debug { "#{annotation_module.qp} annotation #{qp} metadata is complete." }
      end
    
      # Augments +Jinx::Introspector.add_java_attribute+ to accomodate the
      # following caTissue anomaly:
      #
      # @quirk caTissue DE annotation collection attributes are often misnamed,
      #   e.g. +histologic_grade+ for a +HistologicGrade+ collection attribute.
      #   This is fixed by adding a pluralized alias, e.g. +histologic_grades+.
      #
      # @return [Symbol] the new attribute symbol
      def add_java_property(pd)
        # the new property
        prop = super
        # alias a misnamed collection attribute, if necessary
        if prop.collection? then
          name = prop.attribute.to_s
          if name.singularize == name then
            aliaz = name.pluralize.to_sym
            if aliaz != name then
              logger.debug { "Adding annotation #{qp} alias #{aliaz} to the misnamed collection property #{prop}..." }
              delegate_to_property(aliaz, prop)
            end
          end
        end
        prop
      end
  
      # Sets the caTissue 1.2 and higher proxy attribute. The attribute is aliased
      # to the demodulized annotation module name, e.g. +clinical+. A hook attribute
      # is created that is a shortcut for the annotation => proxy => hook reference.
      #
      # @param [Jinx::Property] prop the proxy attribute
      # @param [Symbol, nil] the proxy => hook attribute (default is the underscore demodulized hook class name)
      def set_proxy_property(prop, hook_attr=nil)
        hook_attr ||= prop.type.hook.name.demodulize.underscore.to_sym
        @pxy_prop = prop
    
        # Alias the attribute with the proxy hook name, e.g. the
        # Participant::Clinical::AlcoholAnnotation -> Participant::Clinical::ParticipantRecordEntry
        # proxy reference attribute participant_record_entry is aliased by clinical.
        aliaz = annotation_module.name.demodulize.underscore.to_sym
        if aliaz != prop.to_sym then
          alias_attribute(aliaz, prop.to_sym)
          logger.debug { "Aliased #{qp} #{aliaz} to #{prop}." }
        end
    
        # Make the hook attribute.
        define_method(hook_attr) { pxy = send(aliaz); pxy.hook if pxy }
        define_method("#{hook_attr}=".to_sym) { |obj| pxy = obj.proxy_for(aliaz, self) if obj; send(prop.writer, pxy) }
        add_attribute(hook_attr, prop.type.hook)
        logger.debug { "Defined #{qp} => #{prop.type.hook.qp} hook attribute #{hook_attr}." }
      end
  
      # Wraps the caTissue 1.1.x proxy attribute with a hook argument and return value.
      # If the superclass is a primary annotation, then this method delegates
      # to the superclass to set the proxy attribute. Otherwise, the proxy accessor
      # methods are modified as follows:
      # * the proxy writer converts a hook argument to its proxy
      # * the proxy reader converts a proxy to its hook
      # * the proxy is aliased as a hook attribute, if necessary, e.g.  +participant+
      #   is aliased to +participant_record_entry+
      #
      # @param [Jinx::Property] prop the proxy attribute
      def wrap_1_1_proxy_attribute(prop)
        if prop.nil? then
          raise AnnotationError.new("Cannot convert #{qp} => #{klass.qp} argument to a proxy since no proxy attribute is defined.")
        end
        logger.debug { "Adding #{qp} #{prop} attribute to wrap the proxy Java accessor methods with the hook JRuby accessor methods..." }
        # Wrap the proxy reader with a proxy => hook converter.
        convert_proxy_reader_result_to_hook(prop.reader)
        # the proxy => hook attribute metadata
        pxy_hook_prop = annotation_module.proxy.hook_property
        # the hook => proxy attribute
        hook_pxy_attr = pxy_hook_prop.inverse
        # Wrap the proxy writer with a hook -> proxy converter.
        convert_proxy_writer_hook_argument_to_proxy(prop.writer, hook_pxy_attr)
        # Reset the attribute type.
        hook = pxy_hook_prop.type
        set_attribute_type(prop.to_sym, hook)
        logger.debug { "Reset #{qp} #{prop} type to the hook class #{hook}." }
        # Mark the hook attribute as unsaved. This is necessary because as a uni-directional
        # Java independent reference, the default is to save this attribute. Since we save the
        # proxy reference instead, the convenience hook reference is unsaved.
        prop.qualify(:unsaved)

        # Add the proxy reference attribute.
        pxy_attr = annotation_module.name.demodulize.underscore.to_sym
        @pxy_prop = add_attribute(pxy_attr, annotation_module.proxy, :saved)
        logger.debug { "Added #{qp} => #{@pxy_prop.type} proxy attribute #{@pxy_prop}." }
      end
  
      # @param [ProxyClass] klass the proxy class
      # @return [Jinx::Property] the annotation -> proxy attribute
      def obtain_proxy_property(klass)
        prop = infer_proxy_property(klass) || create_proxy_property(klass)
        if prop.nil? then raise AnnotationError.new("Annotation #{qp} proxy attribute could not be found or created") end
        logger.debug { "Annotation class #{qp} has proxy reference attribute #{prop}." }
        prop
      end
  
      # @param [ProxyClass] klass the proxy class
      # @return [Jinx::Property] the existing annotation -> proxy attribute
      def infer_proxy_property(klass)
        domain_attributes.each_property { |prop| return prop if prop.type == klass and prop.declarer == self }
        nil
      end
  
      # @param [ProxyClass] klass the proxy class
      # @return [Jinx::Property] the new annotation -> proxy attribute
      def create_proxy_property(klass)
        # the proxy attribute symbol
        pa = annotation_module.name.demodulize.underscore.to_sym
        logger.debug { "Creating primary annotation #{qp} => proxy #{klass} attribute #{pa}..." }
        # make the attribute
        attr_accessor(pa)
    
        # Add the attribute. Setting the saved flag ensures that the save template passed to
        # the annotation service includes a reference to the hook object. This in turn allows
        # the annotation service to call the integration service to associate the annotation
        # to the hook object.
        prop = add_attribute(pa, proxy, :saved)
        # make the inverse proxy -> annotation dependent attribute
        inverse = klass.create_annotation_attribute(self)
        logger.debug { "Created primary annotation #{qp} proxy #{klass} attribute #{pa} with inverse #{inverse}." }
    
        prop
      end
  
      # Recursively saves the annotation dependency hierarchy rooted at the given annotation attribute.
      #
      # @param annotation (see #save_annotation)
      # @param [Symbol] attribute the attribute to save
      def save_dependent_attribute(annotation, attribute)
        annotation.send(attribute).enumerate do |ref|
          logger.debug { "Saving annotation #{annotation} #{attribute} dependent #{ref.qp}..." }
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
        awh = {}
        dependent_attributes.each_pair do |pa, prop|
          # skip attributes defined in a superclass
          next unless prop.declarer == self
          if @entity_id.nil? then
            raise AnnotationError.new("Cannot define reference writers for #{qp} since it does not have an entity id.")
          end
          awh[pa] = Annotation::ReferenceWriter.new(@entity_id, prop)
        end
        # If the superclass is also an annotation, then form the union of its writers with the local writers.
        superclass < Annotation && superclass.primary? ? awh + superclass.attribute_writer_hash : awh
      end
  
      # Wraps the proxy reader method to convert a proxy to its hook.
      #
      # @param [Symbol] reader the proxy reader method
      def convert_proxy_reader_result_to_hook(reader)
        redefine_method(reader) do |old_mth|
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
          # Alias the annotation module attribute name to the old method.
          aliaz = "#{annotation_module.name.demodulize.underscore}=".to_sym
          alias_method(aliaz, old_mth)
          lambda do |value|
            # Convert the parameter from a hook to a proxy, if necessary.
            pxy = klass === value ? value.proxy_for(inverse, self) : value
            unless pxy == value then logger.debug { "Converted #{qp} #{writer} argument from hook #{value.qp} to proxy #{pxy.qp}" } end
            send(self.class.proxy_property.writer, pxy)
          end
        end
        logger.debug { "Redefined the #{klass.qp} #{inverse} proxy writer #{writer} to convert a hook #{klass.qp} parameter to the hook proxy." }
      end
    end
  end
end
