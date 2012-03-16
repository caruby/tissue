require 'jinx/resource'
require 'jinx/metadata/id_alias'

# Add the Java jar file to the Java path.
require File.dirname(__FILE__) + '/../ext/bin/clinicaltrials.jar'

module ClinicalTrials
  include Jinx::Resource, Jinx::IdAlias
  
  package 'clinicaltrials.domain'
  
  definitions File.expand_path('clinical_trials', File.dirname(__FILE__))
end

