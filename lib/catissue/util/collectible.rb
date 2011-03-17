require 'caruby/util/validation'

module CaTissue
  # A Collectible mix-in instance can hold a #{ReceivedEventParameters} and a #{CollectedEventParameters}.
  module Collectible
    # Merges the other object into this SpecimenCollectionGroup. This method augments the
    # standard {CaRuby::Resource#merge_attributes} method as follows:
    # * Builds the SpecimenEventParameter objects from atomic parameters, e.g.:
    #     SpecimenCollectionGroup.create(:name = > name, ..., :collector => collector, :receiver => receiver)
    #
    # The supported collectible optons are described in {#collect}.
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
    # @param[{Symbol => Object}] opts the merge options
    # @option opts :specimen_event_parameters the optional SEP merge collection to augment
    # @option opts :receiver the required tissue bank #{CaTissue::User} who received the tissue
    # @option opts :received_date the received date (defaults to now)
    # @option opts :collector the optional #{CaTissue::User} who acquired the tissue from the
    #   #{CaTissue::Participant} (defaults to the receiver)
    # @option opts :collected_date the collection date (defaults to the received date)
    # @return [CaTissue::SpecimenEventParameters] the augmented SEPS
    # @raise [ValidationError] if this SCG has already been received.
    def collect(opts)
      raise ValidationError.new("#{self} is already collected") if received?
      specimen_event_parameters.merge!(extract_event_parameters(opts))
    end

    # Returns whether this SCG has a collected event.
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
   
    #  Overrides {Resource#each_defaults_dependent} to visit the {CaTissue::ReceivedEventParameters} first.
    #
    # @yield [dep] the block to call on the dependent
    # @yield [Resource] the dependent to visit
    def each_defaults_dependent
      # visit ReceivedEventParameters first
      rep = received_event_parameters
      yield rep if rep
      # add other dependent defaults
     each_dependent { |dep| yield dep unless ReceivedEventParameters === dep }
    end

    # Extracts #{CaTissue::ReceivedEventParameters} and #{CaTissue::CollectedEventParameters} from the given
    # options. The options used to build these #{CaTissue::SpecimenEventParameters} are removed, since they
    # are redundant.
    #
    # @param opts (see #collect)
    # @return [CaTissue::SpecimenEventParameters] the augmented SEPS
   def extract_event_parameters(opts)
      # Check if there is an attribute association
      eps = opts.delete(:specimen_event_parameters) || []
      # collect additional parameter associations
      rcvr = opts.delete(:receiver)
      clctr = opts.delete(:collector)
      clctr ||= rcvr
      # if there is not at least a collector, then don't continue parsing
      return eps if clctr.nil?
      rdate = opts.delete(:received_date)
      rdate ||= DateTime.now
      eps << CaTissue::SpecimenEventParameters.create_parameters(:received, self, :user => rcvr, :timestamp => rdate)
      cdate = opts.delete(:collected_date)
      cdate ||= rdate
      eps << CaTissue::SpecimenEventParameters.create_parameters(:collection, self, :user => clctr, :timestamp => cdate)
      logger.debug { "SCG #{self} event parameters: #{eps.pp_s(:single_line)}" }
      eps
    end
  end
end