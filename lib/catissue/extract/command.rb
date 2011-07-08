require 'catissue/cli/command'
require 'catissue/extract/delta'
require 'catissue/extract/extractor'

module CaTissue
  # ExtractCommand extracts target CaTissue domain class objects whose modification date is
  # within a time interval to a CSV file based on a CSV mapping file.
  class ExtractCommand < CaTissue::Command
    # Creates a new ExtractCommand.
    # The delta range is given by the required :since option and optional :before option.
    # The default before value is the current DateTime. These are used to build a Delta
    # which is passed to +CaRuby::Command.initialize+ as the :ids option.
    # The :log option specifies a log file.
    # Other supported options are described in {Extractor#initialize}.
    def initialize
      # prep the options
      since = opts.delete(:since)
      raise ArgumentError.new("Missing required beginning of date selection range option") unless since
      before = opts.delete(:before) || DateTime.now
       # the data acquirer
      opts[:ids] = Delta.new(@target, since, before)
      # make the command
      super(opts)
    end

    # Starts an Extractor with the command-line options.
    def run
      super { |opts| Extractor.new(opts) }
    end
  end
end
