require File.dirname(__FILE__) + '/../../helpers/test_case'
require File.dirname(__FILE__) + '/../../../../../catissue/migration/helpers/test_case'

# Inject migrate methods that simulate administrative setup.
require File.dirname(__FILE__) + '/shims/seed'

module Galena
  module Tissue
    # Tests the Galena example migration.
    module MigrationTestCase
      include CaTissue::MigrationTestCase
    
      # The migration options are obtained from the file named _fixture_+_migration.yaml+
      # in the {CONFIGS} directory.
      #
      # @param [String, nil] the fixtures directory (default {FIXTURES})
      def setup(fixtures=FIXTURES)
        super(fixtures)
      end
      
      private

      # The default migration input data directory.
      FIXTURES = Galena::ROOT_DIR + '/data'
  
      # The default migration shims directory.
      SHIMS = Galena::ROOT_DIR + '/lib/galena/tissue/migration/helpers/shims'
    
      # The dfault migration configuration directory.
      CONFIGS = Galena::ROOT_DIR + '/conf/migration'
      
      # @return [Galena::Seed::Defaults] the administrative objects
      def defaults
        @defaults ||= Galena::Seed.new.uniquify
      end
      
      # Adds the +:target+, +:mapping+ and +:shims+ to the options and delegates
      # to the superclass.
      #
      # @see {CaTissue::MigrationTestCase#create_migrator}
      def create_migrator(fixture, opts={})
        # The fixture config directory.
        dir = File.join(CONFIGS, fixture.to_s)
        opts[:target] ||= CaTissue::TissueSpecimen
        opts[:mapping] ||= File.expand_path('fields.yaml', dir)
        f = File.expand_path('defaults.yaml', dir)
        opts[:defaults] ||= f if File.exists?(f)
        f = File.expand_path('values.yaml', dir)
        opts[:filters] ||= f if File.exists?(f)
        f = File.expand_path("#{fixture}.rb", SHIMS)
        opts[:shims] ||= [f] if File.exists?(f)
        mgtr = super
        if opts[:unique] then
          defaults.protocols.each do |pcl|
            pcl.uniquify
            pcl.events.each { |cpe| cpe.uniquify }
          end
        end
        mgtr
      end
    end
  end
end

