# Borrow the Galena test apparatus.
require 'test/lib/examples/galena/tissue/migration/test_case'

# Tests the PSBIN example migration.
module PSBIN
  class MigrationTest < Test::Unit::TestCase
    include Galena::Tissue::MigrationTestCase
    
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
    #
    # NOTE: Occasionally a test case fails sporadically when run as a suite. Testing individually succeeds.
    # Presumably a test artifact. TODO - isolate. 1.1.2 only?

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
  
    # The default migration input data directory.
    FIXTURES = 'examples/psbin/data'
  
    # The default migration shims directory.
    SHIMS = 'examples/psbin/lib/psbin'
    
    # The dfault migration configuration directory.
    CONFIGS = 'examples/psbin/conf'
    
    PATIENT_OPTS = {
      :target => CaTissue::Participant,
      :mapping => File.join(CONFIGS, 'patient_fields.yaml'),
      :defaults => File.join(CONFIGS, 'patient_defaults.yaml'),
    }
    
    BIOPSY_OPTS = {
      :target => CaTissue::SpecimenCollectionGroup,
      :mapping => File.join(CONFIGS, 'biopsy_fields.yaml'),
      :defaults => File.join(CONFIGS, 'biopsy_defaults.yaml'),
      :shims => [File.join(SHIMS, 'biopsy_shims.rb')]
    }
    
    SURGERY_OPTS = {
      :target => CaTissue::SpecimenCollectionGroup,
      :mapping => File.join(CONFIGS, 'surgery_fields.yaml'),
      :defaults => File.join(CONFIGS, 'surgery_defaults.yaml'),
      :shims => [File.join(SHIMS, 'surgery_shims.rb')]
    }
    
    T_STAGE_OPTS = {
      :target => CaTissue::Participant::Clinical::LabAnnotation,
      :mapping => File.join(CONFIGS, 't_stage_fields.yaml'),
      :defaults => File.join(CONFIGS, 't_stage_defaults.yaml'),
    }
    
    def self.therapy_options(timing, agent)
      target = case agent
        when :hormone then CaTissue::Participant::Clinical::TreatmentAnnotation
        when :radiation then CaTissue::Participant::Clinical::RadRXAnnotation
      end
      {
        :target => target,
        :mapping => File.join(CONFIGS, 'therapy_fields.yaml'),
        :defaults => File.join(CONFIGS, "#{timing}_#{agent}_defaults.yaml")
      }
    end
    
    ADJ_HORMONE_OPTS = therapy_options(:adjuvant, :hormone)
    
    ADJ_RAD_OPTS = therapy_options(:adjuvant, :radiation)
    
    NEOADJ_HORMONE_OPTS = therapy_options(:neoadjuvant, :hormone)
    
    NEOADJ_RAD_OPTS = therapy_options(:neoadjuvant, :radiation)
  end
end
