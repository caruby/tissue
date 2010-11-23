$:.unshift 'lib'
$:.unshift 'test/fixtures/lib'

# load the core gem
require 'rubygems'
begin
  gem 'caruby-core'
rescue LoadError
  # if the gem is not available, then try a local development source
  $:.unshift  '../caruby/lib'
end

# open the logger
LOG_FILE = 'test/results/log/catissue.log' unless defined?(LOG_FILE)
require 'caruby/util/log' and
CaRuby::Log.instance.open(LOG_FILE, :shift_age => 10, :shift_size => 1048576, :debug => true)

$:.unshift '../catissue/lib'
$:.unshift '../catissue/test/fixtures/lib'

require 'catissue'
require 'test/fixtures/lib/catissue/defaults_test_fixture'

module CaTissue
  module TestCase
    attr_reader :database

    def setup
      super()
      logger.info("Testing #{name}...")
      @database = CaTissue::Database.instance
    end

    def teardown
      super
      @database.close if @database
      logger.info("Test #{name} completed.")
    end
    
    def defaults
      @defaults ||= CaTissueTest.defaults.uniquify
    end
    
    # Tests the domain object +add_defaults_local+ method.
    # Subclasses are responsible for setting every attribute that is a pre-condition for default value initialization.
    def verify_defaults(subject)
      subject.add_defaults
      msg = "#{subject.qp} with default attributes fails validation"
      assert_nothing_raised(ValidationError, msg) { subject.validate }
    end

    # Tests saving the subject. Calls {Database#save} on the subject and verifies that subject and its
    # references were persisted.
    def verify_save(subject)
      logger.debug{ "Verifying #{subject.qp} save with content:\n#{subject.dump}" }
      # capture the save operation time
      st = Stopwatch.measure { @database.save(subject) }.elapsed
      # the database execution time
      dt = @database.execution_time
      logger.debug { "#{subject.qp} save took #{'%.2f' % st} seconds, of which #{'%.2f' % dt} were database operations." }
      verify_saved(subject)
    end

    # Tests a query on the given template.
    # The block given to this method is called on the query result.
    def verify_query(template, *path) # :yields: result
      yield database.query(template, *path)
    end

    # Returns the Ruby date as determined by setting a Java Date property.
    def date(year, month, day)
      jdate = java.util.Calendar.instance
      jdate.clear
      jdate.set(year, month - 1, day)
      jdate.time.to_ruby_date
    end

    private
  
    # @param (see #mock_storable_template)
    # @return (see #mock_storable_template)
    def mock_create_template(obj)
      mock_storable_template(obj) { |ref| ref.class.creatable_domain_attributes }
    end
  
    # @param (see #mock_storable_template)
    # @return (see #mock_storable_template)
    def mock_update_template(obj)
      mock_storable_template(obj) { |ref| ref.class.updatable_domain_attributes }
    end
    
    # @param [Resource] obj the domain object to "save"
    # @return [Resource] the template to use in the save operation
    # @yield [ref] the storable attributes
    # @yieldparam [Resource] ref the domain object to "save"
    def mock_storable_template(obj, &selector)
      # add fake identifiers to prerequisite references
      obj.class.storable_prerequisite_attributes.each do |attr|
        obj.send(attr).enumerate { |ref| ref.identifier = 1 }
      end
      # the template builder
      bldr = CaRuby::StoreTemplateBuilder.new(@database, &selector)
      # the save template
      bldr.build_template(obj)
    end

    # Verifies that the given subject and its references were persisted.
    def verify_saved(subject)
      logger.debug { "Verifying saved content of #{subject}..." }
      subject.dependent? ? verify_saved_dependent(subject) : verify_saved_independent(subject)
      logger.debug { "Verified saved content of #{subject}." }
    end

    def verify_saved_dependent(dependent)
      owner = dependent.owner
      assert_not_nil(owner, "Owner missing for dependent: #{dependent}")
      attribute = owner.class.dependent_attribute(dependent.class)
      assert_not_nil(attribute, "Dependent attribute missing for #{dependent} owner #{owner}")
      # a dependent collection reference must be refetched
      if owner.class.collection_attribute?(attribute) then
        verify_saved_dependent_collection_member(dependent, owner, attribute)
      else
        assert_not_nil(dependent.identifier, "Stored dependent #{dependent} identifier is not set")
      end
      verify_saved_content(dependent)
    end

    # Verifies that the given dependent has an identifier and that the given owner dependent attribute value
    # contains the dependent.
    def verify_saved_dependent_collection_member(dependent, owner, attribute)
      dependents = owner.send(attribute)
      assert(dependents.include?(dependent), "Owner #{owner.qp} dependents collection #{attribute} does not contain #{dependent}")
      assert_not_nil(dependent.identifier, "Identifier not set for stored owner #{owner.qp} #{attribute} dependent collection member #{dependent}")
    end

    # Verifies the subject stored content.
    def verify_saved_independent(subject)
      subject_id = subject.identifier
      assert_not_nil(subject_id, "#{subject.class.qp} identifier not set")
      verify_saved_content(subject)
    end

    # Verifies that the given subject matches the database content. Does not verify subject unless it has
    # a secondary key.
    def verify_saved_content(subject)
      attrs = subject.class.secondary_key_attributes
      return if attrs.empty?
      missing = attrs.reject { |attr| subject.send(attr) }
      assert(missing.empty?, "#{subject} is missing values for secondary key attributes #{missing.to_series}")
      # make a secondary key search template
      vh = attrs.to_compact_hash do |attr|
         v = subject.send(attr)
         Resource === v ? v.copy : v
      end
      tmpl = subject.class.new(vh)
      # find the template in the database
      logger.debug  { "Verifying #{subject.qp} by finding and comparing template #{tmpl.pp_s}..." }
      assert_not_nil(tmpl.find, "#{subject} not found in database")
      # compare the subject to the fetched template
      verify_saved_matches_fetched(subject, tmpl)
    end

    # Verifies that the given expected domain object has the same content as actual,
    # and that the dependents match.
    #
    # @param [Resource] expected the saved value
    # @param [Resource] actual the fetched value
    def verify_saved_matches_fetched(expected, actual)
      expected.class.saved_nondomain_attributes.each do |attr|
        # compare attributes that are fetched and set on create
        attr_md = expected.class.attribute_metadata(attr)
        if verify_saved_attribute?(attr_md) then
          eval = expected.send(attr)
          aval = actual.send(attr)
          if eval.nil? then
            assert_nil(aval, "#{expected.qp} was saved without a #{attr} value, but was stored in the database with value #{actual.qp}")
          else
            assert_not_nil(aval, "#{expected.qp} was saved with #{attr} value #{eval.qp}, but this value was not found in the database.")
            assert(CaRuby::Resource.value_equal?(eval, aval), "#{expected.qp} was saved with #{attr} value #{eval.qp} that does not match the database value #{aval.qp}")
          end
        end
      end
      verify_dependents_match(expected, actual)
    end
    
    # @param [AttributeMetadata] attr_md the saved attribute to check
    # @return whether the attribute is fetched, creatable and not volatile
    def verify_saved_attribute?(attr_md)
      attr_md.fetched? and attr_md.creatable? and not attr_md.volatile?
    end

    # Verifies that each expected dependent matches an actual dependent and has the same content.
    def verify_dependents_match(expected, actual)
      expected.class.dependent_attributes.each do |attr|
        edeps = expected.send(attr) || next
        adeps = actual.send(attr)
        logger.debug { "Verifying #{expected.qp} dependent #{attr} #{edeps.qp} against #{actual.qp} #{adeps.qp}..." } unless edeps.nil_or_empty?
        if edeps.collection? then
          edeps.each do |edep|
            adep = edep.match_in_owner_scope(adeps)
            assert_not_nil(adep, "#{expected} #{attr} dependent #{edep} not found in fetched #{adeps.pp_s}")
            verify_saved_matches_fetched(edep, adep)
          end
        else
          edep = edeps; adep = adeps;
          assert_not_nil(adep, "#{expected} #{attr} dependent #{edep} not found in database")
          verify_saved_matches_fetched(edep, adep)
        end
      end
    end
  end
end