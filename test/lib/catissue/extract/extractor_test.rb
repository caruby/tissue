require File.join(File.dirname(__FILE__), '..', 'test_case')
require 'catissue/extract/extractor'

class ExtractorTest < Test::Unit::TestCase
  include CaTissue::TestCase

  CONFIG_DIR = File.join('test', 'fixtures', 'catissue', 'extract', 'conf')

  def test_specimen_write
    config = File.join(CONFIG_DIR, 'spc_extract.yaml')
    spc = defaults.specimen.create
    extractor = CaTissue::Extractor.new(:file => config, :ids => [spc.identifier])
    extractor.run
    mapping = File.join(CONFIG_DIR, 'spc_fields.yaml')
    mapper = CaRuby::CsvMapper.new(mapping, spc.class, extractor.output)
    rec = mapper.csvio.to_a.first
    assert_not_nil(rec, "Specimen record not written")
    mrn = spc.path_value("specimen_collection_group.registration.participant_identifier")
    assert_equal(mrn.to_s, rec[:mrn].to_s, "Specimen MRN incorrect")
    spn = spc.path_value("specimen_collection_group.surgical_pathology_number")
    assert_equal(spn.to_s, rec[:spn].to_s, "Specimen SPN incorrect")
    date = spc.path_value("specimen_collection_group.collection_event_parameters.timestamp")
    assert_equal(date.to_s, rec[:collection_date].to_s, "Specimen collection date incorrect")
    assert_equal(spc.initial_quantity.to_s, rec[:quantity].to_s, "Quantity incorrect")
  end

  def test_scg_write
    config = File.join(CONFIG_DIR, 'scg_extract.yaml')
    scg = defaults.specimen_collection_group.create
    extractor = CaTissue::Extractor.new(:file => config, :ids => [scg.identifier])
    extractor.run
    mapping = File.join(CONFIG_DIR, 'scg_fields.yaml')
    mapper = CaRuby::CsvMapper.new(mapping, scg.class, extractor.output)
    rec = mapper.csvio.to_a.first
    assert_not_nil(rec, "SCG record not written")
    mrn = scg.path_value("registration.participant_identifier")
    assert_equal(mrn.to_s, rec[:mrn].to_s, "SCG MRN incorrect")
    spn = scg.path_value("surgical_pathology_number")
    assert_equal(spn.to_s, rec[:spn].to_s, "SCG SPN incorrect")
    date = scg.path_value("collection_event_parameters.timestamp")
    assert_equal(date.to_s, rec[:collection_date].to_s, "SCG collection date incorrect")
  end
end