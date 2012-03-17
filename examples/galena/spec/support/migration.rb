shared_context 'a migration' do
  # Builds a migrator for the given test fixture with the given options.
  # The options must include at least the migration target.
  # The mapping, defaults, filter and shims options are inferred from the fixture
  # name, and should not be specified in the options argument.
  # 
  # @param [Symbol] fixture the input test data fixture
  # @param [{Symbol => Object}] opts the migration options
  # @return [CaTissue::Migrator] the migrator
  def migrator(fixture, opts)
    # the input file
    input = File.expand_path("#{fixture}.csv", Galena::DATA)
    # the fixture configurations
    fxt_conf = File.expand_path(fixture.to_s, Galena::CONFIGS)
    # the fixture mapping
    mapping = File.expand_path('fields.yaml', fxt_conf)
    mopts = opts.merge(:input => input, :mapping => mapping, :debug => true)
    unless mopts.has_key?(:defaults) then
      # the standard defaults file
      defs = mopts[:defaults] = [File.expand_path('defaults.yaml', Galena::CONFIGS)]
      # the fixture defaults, if any
      fxt_defs = File.expand_path('defaults.yaml', fxt_conf)
      defs << fxt_defs if File.exists?(fxt_defs)
    end
    unless mopts.has_key?(:filters) then
      # the fixture filter, if any
      filter = File.expand_path('values.yaml', fxt_conf)
      mopts[:filters] = filter if File.exists?(filter)
    end
    # the test seed shim
    shims = [File.expand_path('seed.rb', File.dirname(__FILE__) + '/..')]
    # the fixture shims, if any
    fxt_shims = File.expand_path("#{fixture}.rb", Galena::SHIMS)
    shims << fxt_shims if File.exists?(fxt_shims)
    mopts[:shims] = shims
    CaTissue::Migrator.new(mopts)
  end
  
  # @param [Symbol] fixture the input test data fixture
  # @param [{Symbol => Object}] opts the migration options
  # @return [<CaTissue::Resource>] the migrated targets
  # @yield [target] an optional block to process the migration result
  # @yieldparam [CaTissue::Resource] target the migrated target object
  # @see #migrator
  def migrate(fixture, opts, &block)
    mgtr = migrator(fixture, opts)
    mgtr.map do |tgt|
      yield tgt if block_given?
      tgt
    end
  end
  
  # @param [Symbol] fixture the input test data fixture
  # @param [{Symbol => Object}] opts the migration options
  # @return [<CaTissue::Resource>] the migrated targets
  # @yield [target] an optional block to process the migration result
  # @yieldparam [CaTissue::Resource] target the migrated target object
  # @see #migrator
  def migrate_to_database(fixture, opts, &block)
    tgts = []
    db_opts = opts.merge(:database => CaTissue::Database.instance)
    db_opts[:unique] = true unless db_opts.has_key?(:unique)
    mgtr = migrator(fixture, db_opts)
    mgtr.migrate_to_database do |tgt, rec|
      yield tgt if block_given?
      tgts << tgt
    end
    tgts
  end
end
