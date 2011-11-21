require 'caruby/helpers/validation'

module CaTissue
  # A Collectible mix-in instance can hold a #{ReceivedEventParameters} and a #{CollectedEventParameters}.
  module Collectible
    # Builds this collectible domain object's SpecimenEventParameters from atomic parameters.
    #
    # @example
    #   scg = CaTissue::SpecimenCollectionGroup.new(..., :collector => collector, :receiver => receiver)
    #   scg.collection_event_parameters.user #=> collector
    #   scg.received_event_parameters.user #=> receiver
    # @param (see CaRuby::Resource#merge_attributes)
    # @option opts (see #collect)
    def merge_attributes(other, attributes=nil)
      if Hash === other then
        # extract the event parameters
        other[:specimen_event_parameters] = extract_event_parameters(other)
      end
      # delegate to super for standard attribute value merge
      super
    end

    # Collects and receives this {Collectible} with the given options.
    #
    # @param (see #extract_event_parameters)
    # @option opts (see #extract_event_parameters)
    # @raise [CaRuby::ValidationError] if this SCG has already been received
    def collect(opts)
      raise CaRuby::ValidationError.new("#{self} is already collected") if received?
      specimen_event_parameters.merge!(extract_event_parameters(opts))
    end

    # @return [Boolean] whether this SCG has a collected event.
    def collected?
      collection_event_parameters
    end

    # Returns the User who collected this SCG.
    def collector
      ep = collection_event_parameters
      ep.user if ep
    end

    # @return [Date] the date this SCG was donated by the participant.
    def collection_timestamp
      ep = collection_event_parameters
      ep.timestamp if ep
    end

    # Returns the CollectionEventParameters for this specimen group.
    def collection_event_parameters
      event_parameters.detect { |ep| CaTissue::CollectionEventParameters === ep }
    end

    # Returns whether this SCG has a received event.
    def received?
      received_event_parameters
    end

    # Returns the User who received this specimen group.
    def receiver
      ep = received_event_parameters
      ep.user if ep
    end

    # Returns the ReceivedEventParameters for this specimen group.
    def received_event_parameters
      event_parameters.detect { |ep| CaTissue::ReceivedEventParameters === ep }
    end
    
    private
   
    #  Overrides {CaRuby::Resource#each_defaultable_reference} to visit the {CaTissue::ReceivedEventParameters}.
    #
    # @yield (see CaRuby::Resource#each_defaultable_reference)
    def each_defaultable_reference
      # visit ReceivedEventParameters first
      rep = received_event_parameters
      yield rep if rep
      # add other dependent defaults
     super { |dep| yield dep unless ReceivedEventParameters === dep }
    end

    # Extracts #{CaTissue::CollectibleEventParameters} from the given options.
    # The options are removed from the opts paramater.
    #
    # @param [{Symbol => Object}] opts the merge options
    # @option opts [Enumerable] :specimen_event_parameters the optional SEP merge collection to augment
    # @option opts [CaTissue::User] :receiver the required tissue bank user who received the tissue
    # @option opts [Date] :received_date the received date (defaults to now)
    # @option opts [CaTissue::User] :collector the optional user who acquired the tissue from the
    #   #{CaTissue::Participant} (defaults to the receiver)
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
      logger.debug { "SCG #{self} event parameters: #{eps.pp_s(:single_line)}" }
      eps
    end
  end
end