require File.join(File.dirname(__FILE__), 'test_case')

# Tests the Galena example migration.
module Galena
  class FrozenMigrationTest < Test::Unit::TestCase
    include MigrationTestCase
    
    # Makes the {Galena::Defaults#freezer_type} container type hierarchy, if necessary.
    def setup
      super
      defaults.freezer_type.find(:create)
    end
  
    def test_target
      verify_target(:frozen) do |spc|
        pos = spc.position
        assert_not_nil(pos, "#{spc} missing position")
        assert_not_nil(pos.holder, "#{pos} missing storage container")
        assert_same(spc, pos.occupant,"#{pos} occupant incorrect")
      end
    end
  
    def test_save
      verify_save(:frozen)
    end
  end
end
