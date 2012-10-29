require 'catissue/database'
require 'jinx/helpers/lazy_hash'

module CaTissue
  class Role
    attr_reader :identifier
    
    attr_reader :name
    
    # @param [String] the role name
    # @return [Role] the role for the given name
    # @raise [ArgumentError] if there is no such role
    def self.for(name)
      EXTENT[name]
    end
    
    private
    
    EXTENT = Jinx::LazyHash.new do |name|
      result = Database.current.executor.query(ROLE_ID_SQL, name).first
      raise ArgumentError.new("There is no role with the name #{name}") if result.empty?
      Role.new(name, result.first)
    end
    
    # The SQL to find a role id by name.
    ROLE_ID_SQL = 'select role_id from CSM_ROLE where role_name = ?'
    
    def initialize(name, identifier)
      @name = name
      @identifier = identifier
    end
  end
end
    