require 'caruby/helpers/person'

module CaTissue
  # Mix-in for domain classes that define the +first_name+, +last_name+ and optional +middle_name+ attributes.
  module Person
    include CaRuby::Person

    public

    # Returns this Person's name as a Name structure, or nil if there is no last name.
    def name
      middle = middle_name if respond_to?(:middle_name)
      Name.new(last_name, first_name, middle) if last_name
    end

    # Sets this Person's name to the name string or Name object.
    # A string name argument is parsed using Name.parse.
    #
    # @quirk caTissue CaTissue person names are inconsistent: Participant has a middle name, User doesn't.
    def name=(value)
      value = Name.parse(value) if String === value
      # a missing name is equivalent to an empty name for our purposes here
      value = Name.new(nil, nil) if value.nil?
      unless Name === value then
        raise ArgumentError.new("Name argument type invalid; expected <#{Name}>, found <#{value.class}>")
      end
      self.first_name = value.first
      self.last_name = value.last
      self.middle_name = value.middle if respond_to?(:middle_name)
    end
  end
end