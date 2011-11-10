$:.unshift 'lib'

require 'rubygems'
require 'bundler/setup'
Bundler.setup(:test)

require 'test/unit'
require 'rack/test'

# open the logger
LOG_FILE = 'test/results/log/catissue.log' unless defined?(LOG_FILE)
require 'caruby/helpers/log' and
  CaRuby::Log.instance.open(LOG_FILE, :shift_age => 10, :shift_size => 1048576, :debug => true)

require 'caruby/helpers/uniquifier'

# start the service
load File.expand_path('crtws', 'bin')

module CaTissue
  class WebServiceTest < Test::Unit::TestCase
    include Rack::Test::Methods
  
    def app
      Sinatra::Application
    end
    
    def test_id_get
      get '/site/1'
      assert last_response.ok?
      assert_not_nil(last_response.body, "Site with id 1 not found")
      obj = JSON[last_response.body]
      assert_equal(1, obj.identifier, "Find result incorrect")
    end
    
    def test_param_get
      get '/site/', :id => 1
      assert last_response.ok?
      assert_not_nil(last_response.body, "Site with id 1 not found")
      obj = JSON[last_response.body]
      assert_equal(1, obj.identifier, "Find result incorrect")
    end    
    
    def test_params_get
      get '/site/', :id => 1, :name => 'In Transit'
      assert last_response.ok?
      assert_not_nil(last_response.body, "Site with id 1 not found")
      obj = JSON[last_response.body]
      assert_equal(1, obj.identifier, "Find result incorrect")
    end
    
    def test_nonempty_query_result
      get '/sites/', :name => 'In Transit'
      assert last_response.ok?
      assert_not_nil(last_response.body, "Query returned nil rather than an empty array")
      obj = JSON[last_response.body].first
      assert_not_nil(obj, "Site with id 1 not found")
      assert_equal(1, obj.identifier, "Find result incorrect")
    end
    
    def test_empty_query_result
      get '/sites/', :name => 'Test'.uniquify
      assert last_response.ok?
      assert_not_nil(last_response.body, "Query returned nil rather than an empty array")
      result = JSON[last_response.body]
      assert(result.empty?, "Query without match returned non-empty array")
    end
    
    def test_post
      pnt = CaTissue::Participant.new(:last_name => 'Test'.uniquify)
      post '/', :json => pnt.to_json
      assert_not_nil(last_response.body, "Participant not created")
      assert(last_response.body =~ /\d+/, "Participant return value is not an integer")
    end
    
    def test_post_with_dependent
      pnt = CaTissue::Participant.new(:last_name => 'Test'.uniquify)
      CaTissue::Race.new(:participant => pnt, :race_name => 'White')
      post '/', :json => pnt.to_json
      assert_not_nil(last_response.body, "Participant not created")
      assert(last_response.body =~ /\d+/, "Participant return value is not an integer")
      race = CaTissue::Participant.new(:identifier => last_response.body.to_i).find.races.first
      assert_not_nil(race, "Participant race not created")
      assert_equal('White', race.race_name, "Participant race name incorrect")
    end
    
    def test_put
      pnt = CaTissue::Participant.new(:last_name => 'Test'.uniquify).create
      pnt.first_name = 'Saul'
      put '/', :json => pnt.to_json
      assert_not_nil(last_response.body, "Participant not updated")
      assert_equal(pnt.identifier.to_s, last_response.body, "Participant update return value is not the identifier")
    end
    
    def test_put_without_id
      pnt = CaTissue::Participant.new(:social_security_number => '555-56-5656').find(:create)
      pid = pnt.identifier
      pnt.identifier = nil
      pnt.last_name = 'Test'.uniquify
      put '/', :json => pnt.to_json
      assert_not_nil(last_response.body, "Participant not updated")
      assert_equal(pid.to_s, last_response.body, "Participant update return value is not the identifier")
    end
  end
end
