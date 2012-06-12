require 'jinx/helpers/validation'

module CaTissue
  # A Collectible mix-in instance can hold CollectibleEventParameters}.
  module Collectible
    # Augments +Jinx::Resource#merge_attributes+ to builds this collectible domain object's
    # SpecimenEventParameters. If the other source object is a Hash, then it includes
    # both the standard attribute => value associations as well as the options described
    # below. 
    #
    # @example
    #   scg = CaTissue::SpecimenCollectionGroup.new(..., :collector => srg)
    #   scg.collection_event_parameters.user #=> srg
    #
    # @param other [Collectible, {Symbol => Object}] other the source object or Hash
    # @option other [Enumerable] :specimen_event_parameters the optional SEP merge collection to augment
    # @option other [CaTissue::User] :receiver the tissue bank user who received the tissue
    # @option other [Date] :received_date the received date (defaults to now)
    # @option other [CaTissue::User] :collector the user who acquired the tissue
    #   (defaults to the receiver)
    # @option opts [Date] :collected_date the collection date (defaults to the received date)
    def merge_attributes(other, attributes=nil)
      if Hash === other then
        # extract the event parameters
        other[:specimen_event_parameters] = extract_event_parameters(other)
      end
      # delegate to super for standard attribute value merge
      super
    end

    # Collects and receives this Collectible with the given options.
    #
    # @param (see #extract_event_parameters)
    # @option opts (see #extract_event_parameters)
    # @raise [Jinx::ValidationError] if this Collectible has already been received
    def collect(opts)
      raise Jinx::ValidationError.new("#{self} is already collected") if received?
      specimen_event_parameters.merge!(extract_event_parameters(opts))
    end

    # @return [Boolean] whether this Collectible has a collected event.
    def collected?
      collection_event_parameters
    end

    # Returns the User who collected this Collectible.
    def collector
      ep = collection_event_parameters
      ep.user if ep
    end

    # @return [Date] the date this Collectible was donated by the participant.
    def collection_timestamp
      ep = collection_event_parameters
      ep.timestamp if ep
    end

    # Returns the CollectionEventParameters for this Collectible.
    def collection_event_parameters
      event_parameters.detect { |ep| CaTissue::CollectionEventParameters === ep }
    end

    # Returns the {CollectibleEventParameters} for this Collectible.
    def collectible_event_parameters
      event_parameters.select { |ep| CaTissue::CollectibleEventParameters === ep }
    end

    # Returns whether this Collectible has a received event.
    def received?
      received_event_parameters
    end

    # Returns the User who received this Collectible.
    def receiver
      ep = received_event_parameters
      ep.user if ep
    end

    # Returns the ReceivedEventParameters for this Collectible.
    def received_event_parameters
      event_parameters.detect { |ep| CaTissue::ReceivedEventParameters === ep }
    end
    
    private
   
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

    # Extracts #{CaTissue::CollectibleEventParameters} from the given options.
    # The options are removed from the *opts* paramater.
    #
    # @param [{Symbol => Object}] opts the merge options
    # @option opts [Enumerable] :specimen_event_parameters the optional SEP merge collection to augment
    # @option opts [CaTissue::User] :receiver the tissue bank user who received the tissue
    # @option opts [Date] :received_date the received date (defaults to now)
    # @option opts [CaTissue::User] :collector the user who acquired the tissue
    #   (defaults to the receiver)
    # @option opts [Date] :collected_date the collection date (defaults to the received date)
    # @return [CaTissue::SpecimenEventParameters] the augmented SEPS
   def extract_event_parameters(opts)
      # Check if there is an attribute association
      eps = opts.delete(:specimen_event_parameters) || []
      # collect additional parameter associations
      rcvr = opts.delete(:receiver)
      cltr = opts.delete(:collector) || rcvr
      # if there is not at least a collector, then don't continue parsing
      return eps if cltr.nil?
      rdate = opts.delete(:received_date)
      rdate ||= DateTime.now
      eps << CaTissue::SpecimenEventParameters.create_parameters(:received, self, :user => rcvr, :timestamp => rdate)
      cdate = opts.delete(:collected_date)
      cdate ||= rdate
      eps << CaTissue::SpecimenEventParameters.create_parameters(:collection, self, :user => cltr, :timestamp => cdate)
      logger.debug { "Collectible #{self} event parameters: #{eps.pp_s(:single_line)}" }
      eps
    end
  end
end