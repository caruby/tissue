module Galena
  # The Galena example root directory.
  ROOT_DIR = File.expand_path('galena', File.dirname(__FILE__) + '/../../../../../../examples')
end

$:.unshift(Galena::ROOT_DIR + '/lib')

require File.dirname(__FILE__) + '/../../../../catissue/helpers/test_case'
require 'galena/tissue/helpers/seed'
