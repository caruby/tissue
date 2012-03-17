require 'catissue'
require 'catissue/migration/migrator'

module Galena
  # The example data.
  DATA = File.dirname(__FILE__) + '/../data'
  
  # The example configurations.
  CONFIGS = File.dirname(__FILE__) + '/../conf'
  
  # The example shims.
  SHIMS = File.dirname(__FILE__) + '/galena'
  
  # The default log file.
  LOG = File.dirname(__FILE__) + '/../log/galena.log'
  
  # The default results directory.
  RESULTS = File.dirname(__FILE__) + '../results'
end
