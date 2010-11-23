require File.join(File.dirname(__FILE__), '..', 'test_case')

class ParticipantMedicalIdentifierTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @pmi = CaTissue::ParticipantMedicalIdentifier.new
  end

  def test_i_to_s_conversion
    @pmi.medical_record_number = 2
    assert_equal('2', @pmi.medical_record_number, "MRN numeric argument not converted to string")
  end

  # Tests creating and fetching a participant.
  def test_save
    @pmi.medical_record_number = Uniquifier.qualifier
    @pmi.site = defaults.tissue_bank
    @pmi.participant = CaTissue::Participant.new(:name => 'Test Participant'.uniquify)
    verify_save(@pmi)
    # update the PMI
    @pmi.medical_record_number = Uniquifier.qualifier
    verify_save(@pmi)
  end
end
