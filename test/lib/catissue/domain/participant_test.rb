require File.join(File.dirname(__FILE__), '..', 'test_case')
require 'caruby/util/uniquifier'

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
  
  # Tests making a participant lab annotation. 
  def test_lab_annotation
    labs = @pnt.lab_annotations
    assert(labs.empty?, "Labs not empty at start")
    lab = CaTissue::Participant::Clinical::LabAnnotation.new
    lab.merge_attributes(:lab_test_name => 'Test Lab', :participant => @pnt)
    labs = @pnt.lab_annotations
    assert_not_nil(labs.first, "Lab not added to participant labs")
    assert_same(lab, labs.first, "Lab incorrect")
    assert_same(@pnt, lab.owner, "Lab proxy hook not set")
  end

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
  
  def test_save_treatment_annotation
    date = DateTime.new(2010, 10, 10)
    trt = CaTissue::Participant::Clinical::TreatmentAnnotation.new
    trt.merge_attributes(:other_agent => 'Radical Prostatectomy', :participant => @pnt)
    dtn = CaTissue::Participant::Clinical::Duration.new
    dtn.merge_attributes(:start_date => date, :end_date => date, :duration_in_days => 1, :treatment_annotation => trt)
    verify_save(trt)
  end
  
  # caTissue alert - The RadiationTherapy DE class is not supported, since it is not a primary entity.
  # RadRXAnnotation is used instead.  The purpose of the caTissue RadiationTherapy class is unknown,
  # since it adds nothing to RadRXAnnotation. The same consideration applies to Chemotherapy.
  # TODO - check with caTissue support and either request deprecation or add caRuby support.
  def test_save_radiation_annotation
    rdx = CaTissue::Participant::Clinical::RadRXAnnotation.new
    rdx.merge_attributes(:other_agent => 'Adjuvant Radiation Therapy', :participant => @pnt)
    verify_save(rdx)
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