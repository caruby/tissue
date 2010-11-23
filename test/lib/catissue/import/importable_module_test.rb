$:.unshift 'lib'
$:.unshift '../caruby/lib'

require "test/unit"

require 'catissue'

class ImportableTest < Test::Unit::TestCase
  LOG_FILE = 'test/results/catissue/import/log/catissue.log'

  def test_import
    assert_nothing_raised(Exception, 'Java class not imported') { CaTissue::CollectionProtocol }
  end
end