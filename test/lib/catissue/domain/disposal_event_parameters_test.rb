require File.dirname(__FILE__) + '/../../../helpers/test_case'

class DisposalEventParametersTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    specimen = defaults.specimen
    @dsp = CaTissue::DisposalEventParameters.new(:specimen => specimen, :user => specimen.specimen_collection_group.receiver, :reason => 'Test')
  end

  def test_save
    verify_save(@dsp)
  end
end