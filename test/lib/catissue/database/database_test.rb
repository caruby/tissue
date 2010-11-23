require File.join(File.dirname(__FILE__), '..', 'test_case')

class CaTissueDatabaseTest < Test::Unit::TestCase
  LOG_FILE = 'test/results/catissue/log/catissue.log'

  def setup
    CaRuby::Log.instance.open(LOG_FILE, :debug => true)
    @database = CaTissue::Database.instance
  end

  def test_match_specimen
    a = CaTissue::TissueSpecimen.new(:specimen_type => 'Fresh Tissue')
    b = CaTissue::TissueSpecimen.new(:specimen_type => 'Fresh Tissue')
    c1 = a.derive(:specimen_type => 'Fixed Tissue')
    c2 = a.derive(:specimen_type => 'Fixed Tissue')
    d = b.derive(:specimen_type => 'Fixed Tissue')
    e1 = a.derive(:specimen_type => 'Frozen Tissue', :pathological_status => 'Normal')
    e2 = a.derive(:specimen_type => 'Frozen Tissue', :pathological_status => 'Malignant')
    f1 = b.derive(:specimen_type => 'Frozen Tissue', :pathological_status => 'Malignant')
    f2 = b.derive(:specimen_type => 'Frozen Tissue', :pathological_status => 'Normal')
    f3 = b.derive(:specimen_type => 'Frozen Tissue', :pathological_status => 'Normal')
    actual = @database.instance_eval do
      collect_matches([a, e1, c1, e2, c2], [f1, b, f2, d, f3])
    end
    expected = {a => b, c1 => d, e1 => f2, e2 => f1}
    assert_equal(expected, actual, "Specimen match incorrect")
  end
end