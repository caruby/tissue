$:.unshift 'examples/galena/lib'

require 'test/lib/catissue/migration/test_case'
require 'galena/tissue/seed/defaults'

# Inject migrate methods that simulate administrative setup.
require File.join(File.dirname(__FILE__), 'uniquify')

module Galena
  module Tissue
    # Tests the Galena example migration.
    module MigrationTestCase
      include CaTissue::MigrationTestCase
    
      # The default migration input data directory.
      FIXTURES = 'examples/galena/data'
    
      # The default migration shims directory.
      SHIMS = 'examples/galena/lib/galena/tissue/migration'
      
      # The dfault migration configuration directory.
      CONFIGS = 'examples/galena/conf/migration'
    
      # The migration options are obtained from the file named _fixture_+_migration.yaml+
      # in the {CONFIGS} directory.
      #
      # @param [String, nil] the fixtures directory (default {FIXTURES})
      def setup(fixtures=FIXTURES)
        super(fixtures)
      end
      
      private
      
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
          def_file = File.join(CONFIGS, "#{fixture}_defaults.yaml")
          if File.exists?(def_file) then opts[:defaults] = def_file end
        end
        unless opts.has_key?(:shims) then
          shims = File.join(SHIMS, "#{fixture}_shims.rb")
          if File.exists?(shims) then
            opts[:shims] = [shims]
          end    
        end
        super
      end
    end
  end
end

