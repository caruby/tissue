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
    
      # The migration input data directory.
      FIXTURES = 'examples/galena/data'
    
      # The migration input data directory.
      SHIMS = 'examples/galena/lib/galena/tissue/migration'
      
      # The migration configuration directory.
      CONFIGS = 'examples/galena/conf/migration'
    
      # The migration options are obtained from the file named _fixture_+_migration.yaml+
      # in the {CONFIGS} directory.
      def setup
        super(FIXTURES)
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
        def_file = File.join(CONFIGS, "#{fixture}_defaults.yaml")
        if File.exists?(def_file) then opts[:defaults] = def_file end
        shims = File.join(SHIMS, "#{fixture}_shims.rb")
        if File.exists?(shims) then
          sopt = opts[:shims] ||= []
          sopt << shims
        end
        super
      end
    end
  end
end

