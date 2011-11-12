require File.dirname(__FILE__) + '/../../helpers/test_case'
require File.dirname(__FILE__) + '/../../../../../catissue/migration/helpers/test_case'

# Inject migrate methods that simulate administrative setup.
require File.dirname(__FILE__) + '/seed'

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
      SHIMS = Galena::ROOT_DIR + '/lib/galena/tissue/migration'
    
      # The dfault migration configuration directory.
      CONFIGS = Galena::ROOT_DIR + '/conf/migration'
      
      # @return [Galena::Seed::Defaults] the {Galena::Seed.defaults}
      def defaults
        @defaults ||= Galena::Seed.defaults
      end
      
      # Adds the +:target+, +:mapping+ and +:shims+ to the options and delegates
      # to the superclass.
      #
      # @see {CaTissue::MigrationTestCase#create_migrator}
      def create_migrator(fixture, opts={})
        opts[:target] ||= CaTissue::TissueSpecimen
        opts[:mapping] ||= File.join(CONFIGS, "#{fixture}_fields.yaml")
        unless opts.has_key?(:defaults) then
          f = File.join(CONFIGS, "#{fixture}_defaults.yaml")
          if File.exists?(f) then opts[:defaults] = f end
        end
        unless opts.has_key?(:filters) then
          f = File.join(CONFIGS, "#{fixture}_values.yaml")
          if File.exists?(f) then opts[:filters] = f end
        end
        unless opts.has_key?(:shims) then
          f = File.join(SHIMS, "#{fixture}_shims.rb")
          if File.exists?(f) then
            opts[:shims] = [f]
          end    
        end
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

