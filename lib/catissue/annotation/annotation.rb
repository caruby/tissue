require 'jinx/metadata/id_alias'
require 'catissue/resource'
require 'catissue/helpers/hash_code'
require 'catissue/annotation/json'

module CaTissue
  # The annotation error class.
  class AnnotationError < StandardError; end
  
  # The caTissue dynamic extension class mix-in.
  #
  # @quirk caTissue Annotation RecordEntry proxy classes implements hashCode with the identifier.
  #   Consequently, a set member is not found after identifier assignment.
  #   The work-around is to include the HashCode mixin, which reimplements the hash and equality
  #   test methods to be invariant with respect to identifier assignment.
  module Annotation
    include JSON, Resource, HashCode
  end
end
