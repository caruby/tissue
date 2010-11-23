require File.join(File.dirname(__FILE__), '..', 'test_case')
require 'catissue/defaults_test_fixture'

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