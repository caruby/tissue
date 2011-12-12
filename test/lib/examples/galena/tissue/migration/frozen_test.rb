require File.dirname(__FILE__) + '/helpers/test_case'

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
        verify_target(:frozen, :target => CaTissue::TissueSpecimen) do |spc|
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
        verify_save(:frozen, :target => CaTissue::TissueSpecimen)
      end
    end
  end
end
