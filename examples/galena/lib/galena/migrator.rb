require File.expand_path('seed', File.dirname(__FILE__))

module Galena
  module Migrator
    # @return [Galena::Seed] the pre-defined Galena example administrative objects
    def self.administrative_objects
      @seed ||= Galena::Seed.new
    end
  end
end
