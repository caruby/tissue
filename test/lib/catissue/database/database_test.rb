require File.dirname(__FILE__) + '/../../../helpers/test_case'

module CaTissue
  class DatabaseTest < Test::Unit::TestCase
    def test_executor
      assert_nothing_raised("Executor execute failed") do
        CaTissue::Database.instance.executor.execute { |dbh| dbh.execute(SQL) }
      end
      assert_nothing_raised("Executor query failed") do
        CaTissue::Database.instance.executor.query(SQL)
      end
    end
  
    private
  
    SQL = "select count(*) from catissue_site"
  end
end
