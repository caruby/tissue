require 'singleton'
require 'json'
require 'catissue'

module CaTissue
  # The WebService processes catissuews requests.
  class WebService
    include Singleton
    
    # @param [String] the search target class name, singular or plural
    # @param [{String=>String}] params the attribute => value search arguments
    # @return [String, nil] the JSON content of the matching object(s), or nil if no match
    def find(name, params)
      # the caTissue class to find
      sname = name.singularize
      klass = CaTissue.const_get(sname.camelize)
      # the attribute => value hash
      vh = {}
      # convert the HTML parameters into attribute => value entries
      params.each do |k, v|
        # the attribute symbol
        attr = klass.standard_attribute(k)
        # the attribute type
        atype = klass.attribute_metadata(attr).type
        # convert a numeric attribute string argument to an integer 
        v = v.to_i if atype < Java::JavaLang::Number
        vh[attr] = v
      end
      # the search template
      tmpl = klass.new(vh)
      # the search result
      result = sname == name ? tmpl.find : tmpl.query
      # convert the search result, if any, to JSON
      result.to_json if result
    end
    
    # @param [String] json the JSON representation of the object to create
    # @return [String] the created object's identifier as a string 
    def create(json)
      JSON.parse(json).create.identifier.to_s
    end
    
    # @param [String] json the JSON representation of the object to iupdate
    # @return [String] the updated object's identifier as a string 
    def update(json)
      obj = JSON.parse(json)
      if obj.identifier.nil? then
        obj.find or raise NotFoundError.new("Object to update was not found in the database: #{obj}")
      end
      obj.update
      obj.identifier.to_s
    end
  end
end