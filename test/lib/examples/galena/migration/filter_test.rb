require File.join(File.dirname(__FILE__), 'test_case')

# Tests the Galena example migration.
class FilterMigrationTest < Test::Unit::TestCase
  include Galena::MigrationTestCase

  def test_filter
    verify_target(:filter, :bad => BAD_FILE) do |spc|
      assert_not_nil(spc.initial_quantity, "Missing quantity")
      scg = spc.specimen_collection_group
      assert_not_nil(scg, "Missing SCG")
      pnt = scg.registration.participant
      assert_not_nil(pnt, "Missing Participant")
      assert_not_nil(pnt.first_name, "Missing first name")
      assert_not_nil(pnt.last_name, "Missing last name")
    end
  end

  def test_save
    verify_save(:filter, :bad => BAD_FILE)
  end
  
  private
  
  BAD_FILE = 'test/results/examples/galena/bad.csv'
end
