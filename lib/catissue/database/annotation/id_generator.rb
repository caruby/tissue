require 'catissue/database'

module CaTissue
  module Annotation
    # The IdGenerator delegates to the caTissue entity manager to create a new identifier for an annotation.
    class IdGenerator
      def initialize
        @executor = CaTissue::Database.instance.executor
      end

      # @quirk caTissue DE API subquery search fails.
      #   EntityManager.getNextIdentifierForEntity(EntityManager.java:2689) returns zero for some, but not all, DEs.
      #   This is a cascading error that is difficult to trace. The EntityManager.getNextIdentifierForEntity error
      #   is printed to the console rather than propagated up the call stack. A subsequent create then fails because
      #   the identifier is not set.
      #
      #   A candidate work-around is to resolve the DE table name by issuing a direct SQL call and pass this
      #   to DE API EntityManagerUtil.getNextIdentifier. However, EntityManagerUtil is broken as well, for a
      #   different reason.
      #
      #   Another candidate work-around is to get the next id manually from the caTissue DYEXTN_ID_GENERATOR table.
      #   However, this table is suspect since it is not defined as a database sequence generator and is not
      #   referenced in the caTissue source code. It is not used by the caTissue GUI when creating an annotation.
      # 
      #   The work-around to the work-around to the work-around is to call the following SQL directly:
      #     select max(identifier) from <table>
      #   where \<table\> is the result of the EntityManager work-around query. The EntityManager work-around query
      #   is described in
      #   https://cabig-kc.nci.nih.gov/Biospecimen/forums/viewtopic.php?f=19&t=404&p=2785&sid=febe0a1271b3d00020927741a94e9bff#p2785.
      #
      #   Unfortunately, the +select max+ work-around is hampered by the obvious concurrent access race condition.
      #   For an unknown reason, caTissue DE does not use database sequence generators to make DE identifiers.
      #   Even if the caTissue DE API worked, it might suffer from the same race condition. The DE API
      #   EntityManagerUtil caches identifiers. The API call is synchronized, but it is unclear whether each DE
      #   client accesses the same EntityManagerUtil instance as the GUI DE action processor. If not, then the
      #   caTissue DE API, assuming that it were functional, would be open to an even more serious concurrency
      #   conflict than the work-around race condition.
      #
      # @param [String] the entity table
      # @return [Integer] a new identifier for the given annotation object
      def next_identifier(table)
        # Commented line is broken - see method doc.
        # The caTissue EntityManagerUtil hands out table record ids in the work-around.
        #identifier = EntityManagerUtil.getNextIdentifier(table)
        
        logger.debug { "Work around caTissue DE EntityManagerUtil bug by fetching the maximum #{table} identifier directly from the database..." }
        sql = TABLE_MAX_ID_SQL_TMPL % table
        result = @executor.execute { |dbh| dbh.select_one(sql) }
        max = result ? result[0].to_i : 0
        next_id = max + 1
        # End of work-around
        
        logger.debug { "Next #{table} identifier is #{next_id}." }
        next_id
      end
      
      private
      
      TABLE_MAX_ID_SQL_TMPL = "select max(identifier) from %s"
    end
  end
end