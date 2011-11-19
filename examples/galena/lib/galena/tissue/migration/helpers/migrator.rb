require File.dirname(__FILE__) + '/../../helpers/seed'

module Galena
  module Migrator
    # @return [Galena::Seed] the pre-defined Galena example administrative objects
    def self.administrative_objects
      @fixture ||= Galena::Seed.new
    end
  end
end
