require File.dirname(__FILE__) + '/../../helpers/test_case'

class SQLExecutorTest < Test::Unit::TestCase
  def test_executor
    assert_nothing_raised("Executor failed") do
      CaTissue::Database.instance.executor.execute { |dbh| dbh.select_one(SQL) }
    end
  end
  
  private
  
  SQL = "select identifier from catissue_site where name = '#{CaTissue::Site.default_site.name}'"
end
