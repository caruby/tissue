require 'jinx/helpers/validation'
require 'catissue/helpers/action_event_parameters'

module CaTissue
  # A Collectible mix-in instance can hold CollectibleEventParameters}.
  module Collectible
    # Creates an event parameters object of the specified subclass type. The type is the
    # lower-case subclass symbol without the +EventParameters+ suffix, e.g.
    # +:collection+ creates a CollectionEventParameters.
    #
    # The optional params argument are attribute => value associations, e.g.
    #   Collectible.create_parameters(:collection, scg, :user => collector, :timestamp => DateTime.now)
    #
    # @param [Symbol] type the event type
    # @param [Collectible] owner the event owner
    # @param [{Symbol => Object}, nil] opts the attribute => value associations
    def self.create_parameters(type, owner, opts=Hash::EMPTY_HASH)
      # make the class name by joining the camel-cased type prefix to the subclass suffix.
      # classify converts a lower_case, underscore type to a valid class name,
      # e.g. +:check_in_check_out+ becomes +CheckInCheckOut+.
      class_name = type.to_s.classify + SUBCLASS_SUFFIX
      klass = CaTissue.const_get(class_name.to_sym)
      # Make the event parameter.
      ep = klass.new
      # The 2.x event parameters class is an action event DE. The 1.x class is a domain SEP.
      # The 2.x Collectible owner is yet another intermediary, an ActionApplication.
      if klass < ActionEventParameters then
        owner.action_applications << aa = CaTissue::ActionApplication.new
        # Set the event parameter owner.
        ep.action_application = aa
        # Set the action application owner.
        case owner
        when CaTissue::SpecimenCollectionGroup then
          aa.specimen_collection_group = owner
        when CaTissue::Specimen then
          aa.specimen = owner
        else
          raise ArgumentError.new("The #{aa} owner is not a SCG or Specimen: #{owner}")
        end
        logger.debug { "Created #{owner} action application #{aa} for #{ep}." }
      else
        ep.owner = owner
      end
      # Set the other properties.
      ep.merge_attributes(opts)
    end
    
    # Augments +Jinx::Resource#merge_attributes+ to builds this collectible domain object's
    # SpecimenEventParameters. If the other source object is a Hash, then it includes
    # both the standard attribute => value associations as well as the options described
    # below. 
    #
    # @example
    #   scg = CaTissue::SpecimenCollectionGroup.new(..., :collector => surgeon)
    #   scg.collection_event_parameters.user #=> surgeon
    #
    # @param other [Collectible, {Symbol => Object}] other the source object or Hash
    # @option other [Enumerable] :specimen_event_parameters the optional SEP merge collection to augment
    # @option other [CaTissue::User] :receiver the tissue bank user who received the tissue
    # @option other [Date] :received_date the received date (defaults to now)
    # @option other [CaTissue::User] :collector the user who acquired the tissue
    #   (defaults to the receiver)
    # @option opts [Date] :collected_date the collection date (defaults to the received date)
    def merge_attributes(other, attributes=nil, matches=nil, &filter)
      if Hash === other then
        reformat_event_parameter_options(other)
        aeps = other.delete(:action_event_parameters)
        if aeps then
          aas = other[:action_applications] ||= Set.new
          aeps.each { |aep| aas << aep.action_application ||= CaTissue::ActionApplication.new }
        end
      end
      # Delegate to super for standard attribute value merge.
      super
    end
    
    # This method is an alias for +event_parameters+.
    # 
    # @quirk caTissue 2.0 Certain Specimen SpecimenCollectionGroup event parameters are
    #   moved from +specimenEventParameters+ to annotations. caRuby aliases
    #   {#static_event_parameters} to +specimen_event_parameters+. Pre-2.0 caRuby
    #   +specimen_event_parameters+ calls are replaced by {#all_event_parameters}.
    # 
    # @return [<Resource>] the caTissue event parameters Java property value
    # @see #action_event_parameters
    def static_event_parameters
      event_parameters
    end
    
    # Returns this Collectible's action event parameters.
    #
    # @return [<Resource>] the action parameters
    def action_event_parameters
      @aeps ||= make_action_event_parameters_collection
    end
    
    # Deletes the given event parameters object from this Collectible.
    #
    # @param [Resource] ep the event parameters object to delete
    # @return [Boolean] whether the event parameters was deleted
    def delete_event_parameters(ep)
      if static_event_parameters.include?(ep) then
        static_event_parameters.delete(ep)
      elsif self.class.property_defined?(:action_applications) then
        action_applications.any? { |aa| aa.delete_event_parameters(ep) }
      else
        false
      end
    end
      
    # @return [<Resource>] the static and action event parameters
    # @see #static_event_parameters
    def all_event_parameters
      static_event_parameters.union(action_event_parameters)
    end

    # Collects and receives this Collectible with the given options.
    #
    # @param (see #parse_options)
    # @option opts (see #parse_options)
    # @raise [Jinx::ValidationError] if this Collectible has already been received
    def collect(opts)
      raise Jinx::ValidationError.new("#{self} is already collected") if received?
      specimen_event_parameters.merge!(reformat_event_parameter_options(opts))
    end

    # @return [Boolean] whether this Collectible has a collected event.
    def collected?
      collection_event_parameters
    end

    # @return [Resource] the User who collected this Collectible
    def collector
      ep = collection_event_parameters
      ep.user if ep
    end

    # @return [Date] the date this Collectible was donated by the participant
    def collection_timestamp
      ep = collection_event_parameters
      ep.timestamp if ep
    end

    # @return [Resource] the CollectionEventParameters for this Collectible
    def collection_event_parameters
      all_event_parameters.detect { |ep| CaTissue::CollectionEventParameters === ep }
    end

    #  @return [<Resource>] the {CollectibleEventParameters} for this Collectible
    def collectible_event_parameters
      all_event_parameters.select { |ep| CaTissue::CollectibleEventParameters === ep }
    end

    # @return [Boolean] whether this Collectible has a received event
    def received?
      received_event_parameters
    end

    # @return [Resource] the User who received this Collectible
    def receiver
      ep = received_event_parameters
      ep.user if ep
    end

    # @return [Resource] the ReceivedEventParameters for this Collectible
    def received_event_parameters
      all_event_parameters.detect { |ep| CaTissue::ReceivedEventParameters === ep }
    end
    
    private

    # The class name suffix for all event parameter classes.
    SUBCLASS_SUFFIX = 'EventParameters'
    
    # Returns an Enumerable over the action event parameters which reflects changes
    # to the underlying action applications.
    #
    # @return (see #action_event_parameters)
    def make_action_event_parameters_collection
      if self.class.property_defined?(:action_applications) then
        eps = action_applications.transform { |aa| aa.all_event_parameters }
        Jinx::Flattener.new(eps)
      else
        Array::EMPTY_ARRAY
      end
    end
   
    #  Overrides +Jinx::Resource.each_defaultable_reference+ to visit the +CaTissue::ReceivedEventParameters+.
    #
    # @yield (see Jinx::Resource#each_defaultable_reference)
    def each_defaultable_reference
      # visit ReceivedEventParameters first
      rep = received_event_parameters
      yield rep if rep
      # add other dependent defaults
     super { |dep| yield dep unless ReceivedEventParameters === dep }
    end

    # Bulids the {CaTissue::CollectibleEventParameters} from the given options.
    # The +:receiver+ and +:collector+ options are removed from the options.
    # The corresponding collectible parameters are added to the appropriate options.
    #
    # @param [{Symbol => Object}] opts the merge options
    # @option opts [Enumerable] :specimen_event_parameters the optional SEP merge collection to augment
    # @option opts [Enumerable] :action_event_parameters the optional AEP merge collection to augment
    # @option opts [CaTissue::User] :receiver the tissue bank user who received the tissue
    # @option opts [Date] :received_date the received date (defaults to now)
    # @option opts [CaTissue::User] :collector the user who acquired the tissue
    #   (defaults to the receiver)
    # @option opts [Date] :collected_date the collection date (defaults to the received date)
    # @return [<CaTissue::CollectibleEventParameters>] the event parameters
    def reformat_event_parameter_options(opts)
      # collect additional parameter associations
      rcvr = opts.delete(:receiver)
      cltr = opts.delete(:collector) || rcvr
      # if there is not at least a collector, then don't continue parsing
      return opts if cltr.nil?
      # the SEP property option
      eps = if respond_to?(:action_applications) then
        opts[:action_event_parameters] ||= []
      else
        opts[:event_parameters] || (opts[:specimen_event_parameters] ||= [])
      end
      rdate = opts.delete(:received_date)
      rdate ||= DateTime.now
      eps << Collectible.create_parameters(:received, self, :user => rcvr, :timestamp => rdate)
      cdate = opts.delete(:collected_date)
      cdate ||= rdate
      eps << Collectible.create_parameters(:collection, self, :user => cltr, :timestamp => cdate)
      logger.debug { "Collectible #{self} event parameters: #{eps.pp_s(:single_line)}" }
      eps
    end
  end
end