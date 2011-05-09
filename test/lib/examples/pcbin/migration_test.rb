# Borrow the Galena test apparatus.
require 'test/lib/examples/galena/tissue/migration/test_case'

# Tests the PCBIN example migration.
module PCBIN
  class MigrationTest < Test::Unit::TestCase
    include Galena::Tissue::MigrationTestCase
    
    def setup
      super(FIXTURES)
    end

#    def test_patient_target
#      verify_target(:patient, PATIENT_OPTS)
#    end
#
#    def test_biopsy_target
#      verify_target(:biopsy, BIOPSY_OPTS)
#    end
#
#    def test_surgery_target
#      verify_target(:surgery, SURGERY_OPTS)
#    end
#    
#    def test_surgery_target
#      verify_target(:surgery, SURGERY_OPTS)
#    end
#    
#    def test_t_stage_target
#      verify_target(:t_stage, T_STAGE_OPTS)
#    end
#    
#    def test_adj_hormone_target
#      verify_target(:adjuvant_hormone, ADJ_HORMONE_OPTS) 
#    end    
#    
#    def test_adj_radiation_target
#      verify_target(:adjuvant_radiation, ADJ_RADIATION_OPTS) 
#    end    
#    
#    def test_neoadj_hormone_target
#      verify_target(:neoadjuvant_hormone, NEOADJ_HORMONE_OPTS) 
#    end    
#    
#    def test_neoadj_radiation_target
#      verify_target(:neoadjuvant_radiation, NEOADJ_RADIATION_OPTS) 
#    end
    
    ## DATABASE TEST CASES ##
    
    # Tests saving the biopsy, prostatectomy and associated annotations for a single patient.
    # Note that saving the patient first results in an extra caTissue junk anticipated SCG,
    # since the patient migration does not create an SCG and therefore cannot fill in the
    # anticipated SCG. Otherwise, the migrations can be run in any order with the same
    # result.
    def test_save
      logger.debug { "#{qp} saving biopsy SCG..." }
      verify_save(:biopsy, BIOPSY_OPTS)
      logger.debug { "#{qp} saving surgery SCG..." }
      verify_save(:surgery, SURGERY_OPTS) 
      logger.debug { "#{qp} saving patient..." }
      verify_save(:patient, PATIENT_OPTS)
      logger.debug { "#{qp} saving T Stage..." }
      verify_save(:t_stage, T_STAGE_OPTS) 
      logger.debug { "#{qp} saving adjuvant hormone therapy..." }
      verify_save(:adjuvant_hormone, ADJ_HORMONE_OPTS) 
      logger.debug { "#{qp} saving adjuvant radiation therapy..." }
      verify_save(:adjuvant_radiation, ADJ_RADIATION_OPTS) 
      logger.debug { "#{qp} saving neoadjuvant hormone therapy..." }
      verify_save(:neoadjuvant_hormone, NEOADJ_HORMONE_OPTS) 
      logger.debug { "#{qp} saving neoadjuvant radiation therapy..." }
      verify_save(:neoadjuvant_radiation, NEOADJ_RADIATION_OPTS)
    end
    
    private
  
    # The default migration input data directory.
    FIXTURES = 'examples/pcbin/data'
  
    # The default migration shims directory.
    SHIMS = 'examples/pcbin/lib/pcbin'
    
    # The dfault migration configuration directory.
    CONFIGS = 'examples/pcbin/conf'
    
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
    
    ADJ_RADIATION_OPTS = therapy_options(:adjuvant, :radiation)
    
    NEOADJ_HORMONE_OPTS = therapy_options(:neoadjuvant, :hormone)
    
    NEOADJ_RADIATION_OPTS = therapy_options(:neoadjuvant, :radiation)
  end
end
