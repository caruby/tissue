# This file is the entry point included by applications which reference a CaTissue object.

require 'caruby/resource'
require 'catissue/domain'
require 'catissue/annotation/annotatable'

module CaTissue
  # The module included by all CaTissue domain classes.
  #
  # A Resource class is extended to support an attribute -> value hash argument
  # to the initialize method. Subclasses which override the initialize method
  # should not include the hash argument, since it is defined by a class
  # instance new method override rather than initialize to work around a JRuby
  # bug. 
  module Resource
    include CaRuby::Resource, CaRuby::IdAlias, Annotatable
    
    # Returns whether each of the given attribute values either equals the
    # respective other attribute value or one of the values is nil or 'Not Specified'.
    #
    # @param [Resource] other the domain object to compare
    # @param [<Symbol>] attributes the  attributes to compare
    # @return [Boolean} whether this domain object is a tolerant match with the other
    #   domain object on the given attributes
    def tolerant_match?(other, attributes)
      attributes.all? { |attr| Resource.tolerant_value_match?(send(attr), other.send(attr)) }
    end

    # Returns the CaTissue::Database which stores this object.
    def database
      CaTissue::Database.instance
    end

    protected

    # Returns the required attributes which are nil for this domain object.
    # Overrides the CaRuby::Resource method to handle the following bug:
    #
    # @quirk caTissue Bug #67:  AbstractSpecimen.setActivityStatus
    #   is a no-op. The Specimen activityStatus property is incorrectly pulled
    #   up to AbstractSpecimen. AbstractSpecimen.activityStatus is marked as
    #   mandatory, since it is required for Specimen. However, it is not
    #   mandatory, and in fact can't be set, for SpecimenRequirement.
    #   Work-around is to add special code to exclude activityStatus from
    #   the caRuby SpecimenRequirement missing mandatory attributes validation
    #   check.
    def missing_mandatory_attributes
      invalid = super
      # Special case: AbstractSpecimen.setActivityStatus is a no-op.
      if invalid.include?(:activity_status) and CaTissue::SpecimenRequirement === self then
        invalid.delete(:activity_status)
      end
      invalid
    end

    private
    
    # The unspecified value.
    UNSPECIFIED = 'Not Specified'
    
    # @return whether the given value equals the other value or one of the values is nil or 'Not Specified'
    def self.tolerant_value_match?(value, other)
      value == other or unpsecified_value?(value) or unpsecified_value?(other)
    end
    
    # @return whether the given value equals nil or {Resource.UNSPECIFIED}
    def self.unpsecified_value?(value)
      value.nil? or value == UNSPECIFIED
    end
  
    # Add meta-data capability to this Resource module.
    CaTissue.extend_module(self)
  end
end

