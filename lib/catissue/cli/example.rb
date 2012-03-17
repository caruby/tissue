require File.dirname(__FILE__) + '/command'
require 'jinx/helpers/collections'


module CaTissue
  module CLI
    class Example < Command
      def initialize
        super(SPECS) { |opts| list }
      end
      
      private
      
      SPECS = [
        [:list, "-l", "--list", "Prints the example operations and exits"]
      ]
  
      # Lists the examples.
      def list
        root = File.expand_path('examples', File.dirname(__FILE__) + '/../../..')
        raise RuntimeError.new("Examples directory not found: #{root}") unless File.exists?(root)
        Dir.foreach(root) do |f|
          path = File.expand_path(f, root)
          if File.directory?(path) and f[0, 1] != '.' then
            readme = File.join(path, 'doc', 'index.html')
            citation = "(see doc/index.html)" if File.readable?(readme)
            puts "#{f} - #{path} #{citation}"
          end
        end
      end
    end
  end
end