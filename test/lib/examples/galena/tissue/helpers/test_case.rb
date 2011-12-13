require File.dirname(__FILE__) + '/../../../../helpers/test_case'

# Declare the ROOT_DIR constant before adding galena/lib to the Ruby path.

module Galena
  # The Galena example root directory.
  ROOT_DIR = File.expand_path('galena', File.dirname(__FILE__) + '/../../../../../../examples')

  module TestCase
    include CaTissue::TestCase
    
    # Overrides the {CaTissue::TestCase} to reference the {Galena::Seed} defaults.
    #
    # @return [Seed] the test object fixture
    def defaults
      @defaults ||= Seed.new.uniquify
    end
  end
end

# Add galena/lib to the Ruby path.
$:.unshift(Galena::ROOT_DIR + '/lib')

require 'galena/seed'
