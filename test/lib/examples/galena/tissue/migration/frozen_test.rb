require File.join(File.dirname(__FILE__), 'test_case')
require 'galena/tissue/seed/defaults'

module Galena
  module Tissue
    class FrozenMigrationTest < Test::Unit::TestCase
      include MigrationTestCase
      
      # Makes the {Galena::Defaults#freezer_type} container type hierarchy, if necessary.
      def setup
        super
        defaults.freezer_type.find(:create)
      end

      def test_target
        verify_target(:frozen) do |spc|
          assert_equal('Frozen Tissue', spc.specimen_type, "#{spc} type incorrect")
          pos = spc.position
          assert_not_nil(pos, "#{spc} missing position")
          assert_not_nil(pos.holder, "#{pos} missing storage container")
          assert_same(spc, pos.occupant,"#{pos} occupant incorrect")
        end
      end

      def test_save
        # rename the target box
        box = CaTissue::StorageContainer.new(:name => 'Galena Box 7')
        if box.find then
          box.name = box.name.uniquify
          box.save
        end
        verify_save(:frozen)
      end
    end
  end
end
