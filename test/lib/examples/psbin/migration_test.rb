require File.dirname(__FILE__) + '/../../catissue/migration/helpers/test_case'
# Borrow the Galena test apparatus.
require File.dirname(__FILE__) + '/../../examples/galena/tissue/helpers/test_case'
require File.dirname(__FILE__) + '/../../examples/galena/tissue/migration/helpers/seed'

# Tests the PSBIN example migration.
module PSBIN
  class MigrationTest < Test::Unit::TestCase
    include CaTissue::MigrationTestCase, Galena::TestCase
    
    def setup
      super(FIXTURES)
    end

    def test_patient_target
      verify_target(:patient, PATIENT_OPTS)
    end
    
    def test_biopsy_target
      verify_target(:biopsy, BIOPSY_OPTS)
    end
    
    def test_surgery_target
      verify_target(:surgery, SURGERY_OPTS)
    end
    
    def test_t_stage_target
      verify_target(:t_stage, T_STAGE_OPTS)
    end
    
    def test_adj_hormone_target
      verify_target(:adjuvant_hormone, ADJ_HORMONE_OPTS) 
    end
    
    def test_adj_radiation_target
      verify_target(:adjuvant_radiation, ADJ_RAD_OPTS) 
    end
    
    def test_neoadj_hormone_target
      verify_target(:neoadjuvant_hormone, NEOADJ_HORMONE_OPTS) 
    end
    
    def test_neoadj_radiation_target
      verify_target(:neoadjuvant_radiation, NEOADJ_RAD_OPTS) 
    end
    
    ## DATABASE TEST CASES ##

    # Tests saving the biopsy, prostatectomy and associated annotations for a single patient.
    # Note that saving the patient first results in an extra caTissue junk anticipated SCG,
    # since the patient migration does not create an SCG and therefore cannot fill in the
    # anticipated SCG. Otherwise, the migrations can be run in any order with the same
    # result.

    def test_save_biopsy
      logger.debug { "#{qp} saving biopsy SCG..." }
      verify_save(:biopsy, BIOPSY_OPTS)
    end
    
    def test_save_surgery
      logger.debug { "#{qp} saving surgery SCG..." }
      verify_save(:surgery, SURGERY_OPTS)
    end

    def test_save_patient
      logger.debug { "#{qp} saving patient..." }
      verify_save(:patient, PATIENT_OPTS)
    end
    
    def test_save_tstage
      logger.debug { "#{qp} saving T Stage..." }
      verify_save(:t_stage, T_STAGE_OPTS)
    end
    
    def test_save_adjuvant_hormone
      logger.debug { "#{qp} saving adjuvant hormone therapy..." }
      verify_save(:adjuvant_hormone, ADJ_HORMONE_OPTS)
    end
    
    def test_save_adjuvant_radiation
      logger.debug { "#{qp} saving adjuvant radiation therapy..." }
      verify_save(:adjuvant_radiation, ADJ_RAD_OPTS)
    end
    
    def test_save_neoadjuvant_hormone
      logger.debug { "#{qp} saving neoadjuvant hormone therapy..." }
      verify_save(:neoadjuvant_hormone, NEOADJ_HORMONE_OPTS)
    end   
    
    def test_save_neoadjuvant_radiation
      logger.debug { "#{qp} saving neoadjuvant radiation therapy..." }
      verify_save(:neoadjuvant_radiation, NEOADJ_RAD_OPTS)
    end
    
    private
  
    # The migration input data directory.
    FIXTURES = File.dirname(__FILE__) + '/../../../../examples/psbin/data'
  
    # The migration shims directory.
    SHIMS = File.dirname(__FILE__) + '/../../../../examples/psbin/lib/psbin/'
    
    # The migration configuration directory.
    CONFIGS = File.dirname(__FILE__) + '/../../../../examples/psbin/conf'
    
    PATIENT_OPTS = {
      :target => CaTissue::Participant,
      :mapping => File.expand_path('patient_fields.yaml', CONFIGS),
      :defaults => File.expand_path('patient_defaults.yaml', CONFIGS),
    }
    
    BIOPSY_OPTS = {
      :target => CaTissue::SpecimenCollectionGroup,
      :mapping => File.expand_path('biopsy_fields.yaml', CONFIGS),
      :defaults => File.expand_path('biopsy_defaults.yaml', CONFIGS),
      :shims => File.expand_path('biopsy.rb', SHIMS)
    }
    
    SURGERY_OPTS = {
      :target => CaTissue::SpecimenCollectionGroup,
      :mapping => File.expand_path('surgery_fields.yaml', CONFIGS),
      :defaults => File.expand_path('surgery_defaults.yaml', CONFIGS),
      :shims => File.expand_path('surgery.rb', SHIMS)
    }
    
    T_STAGE_OPTS = {
      :target => CaTissue::Participant::Clinical::LabAnnotation,
      :mapping => File.expand_path('t_stage_fields.yaml', CONFIGS),
      :defaults => File.expand_path('t_stage_defaults.yaml', CONFIGS),
    }
    
    def self.therapy_options(timing, agent)
      target = case agent
        when :hormone then CaTissue::Participant::Clinical::TreatmentAnnotation
        when :radiation then CaTissue::Participant::Clinical::RadRXAnnotation
      end
      {
        :target => target,
        :mapping => File.expand_path('therapy_fields.yaml', CONFIGS),
        :defaults => File.expand_path("#{timing}_#{agent}_defaults.yaml", CONFIGS)
      }
    end
    
    ADJ_HORMONE_OPTS = therapy_options(:adjuvant, :hormone)
    
    ADJ_RAD_OPTS = therapy_options(:adjuvant, :radiation)
    
    NEOADJ_HORMONE_OPTS = therapy_options(:neoadjuvant, :hormone)
    
    NEOADJ_RAD_OPTS = therapy_options(:neoadjuvant, :radiation)
  end
end
