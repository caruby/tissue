require File.join(File.dirname(__FILE__), '..', 'test_case')
require 'caruby/util/uniquifier'

require 'json'

class ParticipantTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @pnt = CaTissue::Participant.new(:name => 'Test Participant'.uniquify)
  end

  def test_defaults
    verify_defaults(@pnt)
  end

  # Tests parsing the patient name.
  def test_name
    @pnt.name = 'John Q. Doe'
    assert_equal('John', @pnt.first_name, 'Person first name incorrect')
    assert_equal('Q.', @pnt.middle_name, 'Person middle name incorrect')
    assert_equal('Doe', @pnt.last_name, 'Person last name incorrect')
  end

  # Tests the participant SSN secondary key and MRN alternate key.
  def test_key
    mrn = '5555'
    pmi = @pnt.add_mrn(defaults.tissue_bank, '5555')
    assert_equal(pmi, @pnt.key, 'Person key is not the MRN')
    # add the preferred SSN key
    expected = @pnt.social_security_number = '555-55-5555'
    assert_equal(expected, @pnt.key, 'Person key is not the SSN')
  end

  def test_treatment_annotation
    trt = CaTissue::Participant::Clinical::TreatmentAnnotation.new
    trt.merge_attributes(:agent => 'ACACIA', :participant => @pnt)
    dur = CaTissue::Participant::Clinical::Duration.new
    dur.merge_attributes(:start_date => DateTime.new(2010, 10, 10), :end_date => DateTime.new(2010, 12, 10), :treatment => trt)
    cln = @pnt.clinical.first
    assert_not_nil(cln, "Clinical annotation not added to participant")
    trts = cln.treatment_annotations
    assert_not_nil(trts.first, "Treatment not added to participant annotations")
    assert_same(trt, trts.first, "Treatment incorrect")
    assert_same(@pnt, trt.hook, "Treatment proxy hook not set")
    assert_not_nil(trt.durations.first, "Duration not added to treatment annotation")
    assert_same(dur, trt.durations.first, "Treatment duration incorrect")
  end

  def test_exposure_annotation
    exp = CaTissue::Participant::Clinical::EnvironmentalExposuresHealthAnnotation.new
    exp.merge_attributes(:years_agent_free => 2, :participant => @pnt)
    cln = @pnt.clinical.first
    assert_not_nil(cln, "Clinical annotation not added to participant")
    exps = cln.environmental_exposures_health_annotations
    assert_not_nil(exps.first, "Exposures not added to participant annotations")
    assert_same(exp, exps.first, "Exposures incorrect")
    assert_same(@pnt, exp.hook, "Exposure proxy hook not set")
  end
  
  def test_alcohol_annotation
    alc = CaTissue::Participant::Clinical::AlcoholHealthAnnotation.new
    alc.merge_attributes(:drinks_per_week => 4, :years_agent_free => 2, :participant => @pnt)
    cln = @pnt.clinical.first
    assert_not_nil(cln, "Clinical annotation not added to participant")
    alcs = cln.alcohol_health_annotations
    assert_not_nil(alcs.first, "Alcohol health not added to participant annotations")
    assert_same(alc, alcs.first, "Alcohol health incorrect")
    assert_same(@pnt, alc.hook, "Alcohol health proxy hook not set")
  end
  
  # Tests making a participant lab annotation. 
  def test_lab_annotation
    lab = CaTissue::Participant::Clinical::LabAnnotation.new
    lab.merge_attributes(:lab_test_name => 'Test Lab', :participant => @pnt)
    cln = @pnt.clinical.first
    assert_not_nil(cln, "Clinical annotation not added to participant")
    labs = cln.lab_annotations
    assert_not_nil(labs.first, "Lab not added to participant labs")
    assert_same(lab, labs.first, "Lab incorrect")
    assert_same(@pnt, lab.hook, "Lab proxy hook not set")
  end
  
  def test_radiation_annotation
    if CaTissue::Participant::Clinical::RadiationTherapy != CaTissue::Participant::Clinical::RadRXAnnotation then
      assert_raises(CaTissue::AnnotationError, "RadiationTherapy is not deprecated.") { CaTissue::Participant::Clinical::RadiationTherapy.new}
    end
  end  

  def test_chemotherapy_annotation
    if CaTissue::Participant::Clinical::Chemotherapy != CaTissue::Participant::Clinical::ChemoRXAnnotation then
      assert_raises(CaTissue::AnnotationError, "Chemotherapy is not deprecated.") { CaTissue::Participant::Clinical::Chemotherapy.new}
    end
  end
  
  def test_json
    CaTissue::Race.new(:participant => @pnt, :race_name => 'White')
    dup = JSON[@pnt.to_json]
    race = dup.races.first
    assert_not_nil(race, "Race not serialized")
    assert_equal('White', race.race_name, "Race name not serialized correctly")
    assert_same(dup, race.participant, "Race participant not serialized correctly")
  end

   ## DATABASE TEST CASES

  # Tests creating a participant.
  def test_save
    verify_save(@pnt)
  end

  def test_save_alcohol_annotation
    alc = CaTissue::Participant::Clinical::AlcoholHealthAnnotation.new
    alc.merge_attributes(:drinks_per_week => 4, :years_agent_free => 2, :participant => @pnt)
    verify_save(alc)
  end

  # Tests saving a participant lab annotation. 
  def test_save_lab_annotation
    date = DateTime.new(2010, 10, 10)
    lab = CaTissue::Participant::Clinical::LabAnnotation.new
    lab.merge_attributes(:other_lab_test_name => 'Test Lab', :test_date => date, :participant => @pnt)
    verify_save(lab)
    assert_not_nil(lab.identifier, "Lab not saved")
  end
  
  # Tests saving a participant lab annotation indirectly as a dependent. 
  def test_save_lab_annotation_dependent
    date = DateTime.new(2010, 10, 10)
    lab = CaTissue::Participant::Clinical::LabAnnotation.new
    lab.merge_attributes(:other_lab_test_name => 'Test Lab', :test_date => date, :participant => @pnt)
    verify_save(@pnt)
    assert_not_nil(lab.identifier, "Lab not saved")
  end
  
  # Tests saving a participant treatment annotation. 
  def test_save_treatment_annotation
    trt = CaTissue::Participant::Clinical::TreatmentAnnotation.new
    trt.merge_attributes(:agent => 'ACACIA', :participant => @pnt)
    dur = CaTissue::Participant::Clinical::Duration.new
    dur.merge_attributes(:start_date => DateTime.new(2010, 10, 10), :end_date => DateTime.new(2010, 12, 10), :treatment => trt)
    verify_save(trt)
    assert_not_nil(trt.identifier, "Treatment not saved")
    assert_not_nil(dur.identifier, "Treatment duration not saved")
  end
  
  # Exercises creation of both a HealthExaminationAnnotation and a NewDiagnosisHealthAnnotation.
  # These annotation classes are both primary and share a comman ancestor entity used
  # as the basis for generating database identifiers.
  def test_save_diagnosis_annotation
    date = DateTime.new(2010, 10, 10)
    ndgn = CaTissue::Participant::Clinical::NewDiagnosisHealthAnnotation.new
    ndgn.merge_attributes(:name_of_procedure => 'Biopsy of prostate', :date_of_examination => date, :participant => @pnt)
    verify_save(ndgn)
    date = DateTime.new(2010, 12, 10)
    hdgn = CaTissue::Participant::Clinical::HealthExaminationAnnotation.new
    hdgn.merge_attributes(:other_procedure => 'Post-biopsy exam', :date_of_examination => date, :participant => @pnt)
    verify_save(hdgn)
  end
  
  def test_save_radiation_annotation
    rad = CaTissue::Participant::Clinical::RadRXAnnotation.new
    rad.merge_attributes(:other_agent => 'Adjuvant Radiation Therapy', :participant => @pnt)
    verify_save(rad)
  end
  
  def test_save_chemo_annotation
    chm = CaTissue::Participant::Clinical::ChemoRXAnnotation.new
    chm.merge_attributes(:other_agent => 'Adjuvant Chemotherapy', :participant => @pnt)
    verify_save(chm)
  end
  
  def test_save_exam_annotation
    exam = CaTissue::Participant::Clinical::HealthExaminationAnnotation.new
    exam.merge_attributes(:name_of_procedure => 'Prostatectomy', :participant => @pnt)
    verify_save(exam)
  end
  
  def test_save_recurrence_exam_annotation
    exam = CaTissue::Participant::Clinical::LocalRecurrenceHealthExaminationAnnotation.new
    exam.merge_attributes(:name_of_procedure => 'Prostatectomy', :clinical_diagnosis => 'Malignant melanoma - NOS', :participant => @pnt)
    verify_save(exam)
  end
end