require 'jinx/metadata/id_alias'
require 'caruby/resource'
require 'catissue/helpers/initializer'
require 'catissue/database'

# The caTissue-specific Resource mix-in.
module CaTissue
  module Resource
    include Jinx::IdAlias, Initializer, CaRuby::Resource

    # Returns whether each of the given attribute values either equals the
    # respective other attribute value or one of the values is nil or 'Not Specified'.
    #
    # @param [Resource] other the domain object to compare
    # @param [<Symbol>] attributes the  attributes to compare
    # @return [Boolean} whether this domain object is a tolerant match with the other
    #   domain object on the given attributes
    def tolerant_match?(other, attributes)
      attributes.all? { |pa| Resource.tolerant_value_match?(send(pa), other.send(pa)) }
    end

    # @return [Database] the database which stores this object
    def database
      Database.current
    end

    # Post-processes the +CaRuby#merge_attribute+ result to work around the following
    # caTissue bug:
    #
    # @quirk caTissue The caTissue domain object hashCode is often poorly chosen as
    #   the database identifier. Consequently, a Java Set can no longer detect set
    #   membership of a member after the identifier property is set. caRuby works
    #   around this bug by rehashing a Set property value after content is merged
    #   into this domain object from a fetched domain object.
    #
    # @param (see Jinx::Mergeable#merge_attribute)
    def merge_attribute(attribute, newval, matches=nil)
      mgdval = super
      if Java::JavaUtil::Set === mgdval and not mgdval.empty? then
        content = mgdval.to_a
        mgdval.clear
        content.each { |item| mgdval << item }
        logger.debug { "Worked around a caTissue bug by rebuilding the #{self} #{attribute} value." }
      end
      mgdval
    end

    protected

    # Returns the required attributes which are nil for this domain object.
    # Overrides the Jinx::Resource method to handle the following bug:
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

    # The unspecified default value.
    # @private
    UNSPECIFIED = 'Not Specified'

    # @return [Boolean] whether the given value equals the other value or one of the values is nil or 'Not Specified'
    def self.tolerant_value_match?(value, other)
      value == other or unpsecified_value?(value) or unpsecified_value?(other)
    end

    # @return [Boolean] whether the given value equals nil or {Resource.UNSPECIFIED}
    def self.unpsecified_value?(value)
      value.nil? or value == UNSPECIFIED
    end
  end
end

