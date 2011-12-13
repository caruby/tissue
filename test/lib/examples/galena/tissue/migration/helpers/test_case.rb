require File.dirname(__FILE__) + '/../../../../../catissue/migration/helpers/test_case'
require File.dirname(__FILE__) + '/../../helpers/test_case'
require File.dirname(__FILE__) + '/seed'

module Galena
  module Tissue
    module MigrationTestCase
      include CaTissue::MigrationTestCase, TestCase
    
      def setup
        super(FIXTURES)
      end
      
      def create_migrator(fixture, opts={})
        # The fixture config directory.
        dir = File.join(CONF_DIR, fixture.to_s)
        # The required field heading => caTissue mapping file.
        opts[:mapping] ||= File.expand_path('fields.yaml', dir)
        # The optional caTissue property => default value file.
        dfile = File.expand_path('defaults.yaml', dir)
        opts[:defaults] ||= dfile if File.exists?(dfile)
        # The optional input value => caTissue value file.
        ffile = File.expand_path('values.yaml', dir)
        opts[:filters] ||= ffile if File.exists?(ffile)
        # The optional shims.
        sfile = File.expand_path("#{fixture}.rb", SHIMS_DIR)
        opts[:shims] ||= sfile if File.exists?(sfile)
        super
      end
      
      private
      
      # The migration input data directory.
      FIXTURES = File.join(Galena::ROOT_DIR, 'data')
      
      # The config directory.
      CONF_DIR = File.join(Galena::ROOT_DIR, 'conf', 'migration')
      
      # The shims directory.
      SHIMS_DIR = File.join(Galena::ROOT_DIR, 'lib', 'galena')
    end
  end
end
