require 'caruby/helpers/properties'
require 'caruby/csv/csv_mapper'
require 'caruby/csv/csvio'

module CaTissue
  # Extracts caTissue objects.
  class Extractor
    include Enumerable

    # The default name of this migrator.
    DEF_NAME = 'caTissue Extractor'

    # The extract output file
    attr_reader :output

    # Creates a new Extractor with the given options.
    #
    # @option options [String] :file the extract configuration file name
    # @option options [String] :name name of this Migrator (default is +caTissue Migrator+)
    # @option options [String] :output optional output CSV file name
    # @option options [String] :target required target domain class or class name
    # @option options [String] :ids the database identifiers of the target objects to extract
    # @option options [String] :log log file (default +log/extract.log+)
    def initialize(options={})
      conf_file = options.delete(:file)
      if conf_file then
        CaRuby::Properties.new(conf_file, :array => [:shims]).each { |key, value| options[key.to_sym] ||= value }
      end
      # tailor the options
      name = options[:name] || DEF_NAME
      super(name)
      @ids = options[:ids]
      raise ArgumentError.new("Missing required ids option") unless @ids
      # convert the required target to a CaTissue class if necessary
      @target = target_class_from_option(options[:target])
      @target ||= CaTissue::Specimen
      # the CSV output file
      @output = options[:output]
      raise ArgumentError.new("Missing required extract output file option") unless @output
      # the field mapping configuration
      fld_conf = options[:mapping]
      mapper = CaRuby::CsvMapper.new(fld_conf, @target, @output, :mode => "w")
      @csvio = mapper.csvio
      @fld_path_hash = {}
      mapper.paths.each do |path|
        fld = mapper.header(path)
        # the path node is either an attribute symbol or attribute metadata;
        # if metadata, then use the reader method.
        @fld_path_hash[fld] = path.map { |attr_or_md| CaRuby::Domain::Attribute === attr_or_md ? attr_or_md.reader : attr_or_md }
      end
      logger.debug { "Extract field => path map: #{@fld_path_hash.transform { |path| path.join('.') }.pp_s}" }
    end

    # Exports the selected target records from the database to the output file.
    def run
      begin
        extract { |obj| write(obj) }
      ensure
        @csvio.close
      end
    end

    # Executes this extractor CSV file and calls the block given to this method on each target domain object.
    def extract
      logger.debug { "Found #{@ids.size} extract targets." }
      CaTissue::Database.instance.open do
        @ids.each do |identifier|
          obj = @target.new(:identifier => identifier)
          logger.debug { "Finding extract target #{obj}..." }
          if obj.find then
            logger.debug { "Extractor fetched #{obj}." }
            yield obj
          else
            logger.debug { "Extract target #{obj} not found." }
          end
        end
      end
    end

    alias :each :extract

    private

    def write(obj)
      # collect the field values in order by resolving the path on obj
      rec = @csvio.headers.map do |fld|
        obj.path_value(@fld_path_hash[fld])
      end
      @csvio << rec
      logger.debug { "Extractor wrote #{obj} to CSV output file." }
    end

    def target_class_from_option(option)
      return if option.nil?
      return option if Class === option
      CaTissue.const_get(option)
    end
  end
end