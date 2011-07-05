require 'caruby/resource'
require 'caruby/domain/id_alias'
require 'catissue/domain/hash_code'

module CaTissue
  # Annotation acceess error class.
  class AnnotationError < StandardError; end
  
  # Annotation is the caTissue dynamic extension class mix-in.
  #
  # @quirk caTissue Annotation RecordEntry proxy classes implements hashCode with the identifier.
  #   Consequently, a set member is not found after identifier assignment.
  #   The work-around is to include the HashCode mixin, which reimplements the hash and equality
  #   test methods to be invariant with respect to identifier assignment.
  module Annotation
    include CaRuby::Resource, CaRuby::IdAlias, HashCode

    # @return [Database] the database which stores this object
    def database
      CaTissue::Database.instance
    end
  end
end
