require File.dirname(__FILE__) + '/../helper'
require 'test/unit'
require 'caruby/database/writer_template_builder'

module CaTissue
  module TestCase
    attr_reader :database

    def setup
      super
      logger.info("Testing #{name}...")
      @database = Database.instance
    end

    def teardown
      super
      @database.close if @database
      logger.info("Test #{name} completed.")
    end

    # @return [Seed] the test object fixture
    def defaults
      @defaults ||= Seed.new.uniquify
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
    #
    # @param [Resource] subject the object to save
    def verify_save(subject)
      logger.debug{ "Verifying #{subject.qp} save with content:\n#{dump(subject)}" }
      # capture the save operation time
      @database.clear
      st = CaRuby::Stopwatch.measure { @database.open { |db| db.save(subject) } }.elapsed
      # the database execution time
      dt = @database.execution_time
      logger.debug { "#{subject.qp} save took #{'%.2f' % st} seconds, of which #{'%.2f' % dt} were database operations." }
      verify_saved(subject)
    end

    # Verifies that the given subject and its references were persisted.
    #
    # @param [Resource] subject the saved object to verify
    def verify_saved(subject)
      logger.debug { "Verifying saved content of #{subject}..." }
      subject.dependent? ? verify_saved_dependent(subject) : verify_saved_independent(subject)
      logger.debug { "Verified saved content of #{subject}." }
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
    
    def dump(obj)
      @database.lazy_loader.suspend { obj.dump }
    end
  
    # @param (see #mock_writer_template)
    # @return (see #mock_writer_template)
    def mock_create_template(obj)
      mock_writer_template(obj) { |ref| ref.class.creatable_domain_attributes }
    end
  
    # @param (see #mock_writer_template)
    # @return (see #mock_writer_template)
    def mock_update_template(obj)
      mock_writer_template(obj) { |ref| ref.class.updatable_domain_attributes }
    end
    
    # @param [Resource] obj the domain object to "save"
    # @return [Resource] the template to use in the save operation
    # @yield [ref] the savable attributes
    # @yieldparam [Resource] ref the domain object to "save"
    def mock_writer_template(obj, &selector)
      # the mock template builder
      bldr = CaRuby::Database::Writer::TemplateBuilder.new(@database, &selector)
      class << bldr
        # Adds fake identifiers to the prerequisite references.
        def collect_prerequisites(obj)
          super.each { |ref|  ref.identifier = 1 }
          Array::EMPTY_ARRAY
        end
      end
      # the save template
      bldr.build_template(obj)
    end

    def verify_saved_dependent(dependent)
      verify_dependency(dependent)
      verify_saved_content(dependent)
    end
    
    def verify_dependency(dependent)
      return if dependent.class.owner_attribute.nil?
      # kludge for annotation proxy nonsense (cf. Annotation#owner)
      ownr = Annotation === dependent ? (dependent.proxy or dependent.owner) : dependent.owner
      assert_not_nil(ownr, "Owner missing for dependent: #{dependent}")
      attr = ownr.class.dependent_attribute(dependent.class)
      assert_not_nil(attr, "#{ownr.class.qp} => #{dependent.class.qp} reference attribute not found")
      # a dependent collection reference must be refetched
      if ownr.class.collection_attribute?(attr) then
        verify_saved_dependent_collection_member(dependent, ownr, attr)
      else
        assert_not_nil(dependent.identifier, "Stored dependent #{dependent} identifier is not set")
      end
    end

    # Verifies that the given dependent has an identifier and that the given owner dependent attribute value
    # contains the dependent.
    #
    # @quirk JRuby Set include? incorrectly returns false in the OHSU PSR samples_test test_save_grade
    #   call to this method. Work around by using Set detect rather than include?.
    def verify_saved_dependent_collection_member(dependent, owner, attribute)
      deps = owner.send(attribute)
      assert(deps.detect { |dep| dep == dependent }, "Owner #{owner.qp} #{attribute} value #{deps.pp_s} does not contain #{dependent}")
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
      rqd = attrs & subject.class.mandatory_attributes
      missing = rqd.reject { |attr| subject.send(attr) }
      assert(missing.empty?, "#{subject} is missing values for required secondary key attributes #{missing.to_series}")
      # make a secondary key search template
      vh = attrs.to_compact_hash do |attr|
         v = subject.send(attr)
         Resource === v ? v.copy : v
      end
      # return if there is a missing optional secondary key attribute
      return unless vh.size == attrs.size
      tmpl = subject.class.new(vh)
      # find the template in the database
      logger.debug  { "Verifying #{subject.qp} by finding and comparing template #{tmpl.pp_s}..." }
      assert_not_nil(tmpl.find, "#{subject} not found in database")
      # compare the subject to the fetched template
      verify_that_saved_matches_fetched(subject, tmpl)
    end

    # Verifies that the given expected domain object has the same content as actual,
    # and that the dependents match.
    #
    # @quirk caTissue caTissue mutilates an unspecified specimen type available quantity, e.g.
    #   changing a Specimen with specimen type 'Not Specified' from available quantity 1, initial
    #   quantity 1 to available quantity 0, initial quantity 3 results in available quantity 2
    #   in database. The update is necessary when creating the Specimen with available quantity 0,
    #   initial quantity 3 to work around a different caTissue bug. Thus, the bug work-around
    #   is broken by a different caTissue bug.
    #
    # @param [Resource] expected the saved value
    # @param [Resource] actual the fetched value
    def verify_that_saved_matches_fetched(expected, actual)
      expected.class.saved_nondomain_attributes.each do |attr|
        # available_quantity broken for spc type Not Specified; see quirk above.
        # TODO - Compare attributes that are fetched and set on create.
        attr_md = expected.class.attribute_metadata(attr)
        if verify_saved_attribute?(attr_md) then
          eval = expected.database.lazy_loader.suspend { expected.send(attr) }
          next if eval.nil_or_empty?
          aval = actual.send(attr)
          if eval.nil? then
            assert_nil(aval, "#{expected.qp} was saved without a #{attr} value, but was stored in the database with value #{actual.qp}")
          else
            assert_not_nil(aval, "#{expected.qp} was saved with #{attr} value #{eval.qp}, but this value was not found in the database.")
            if attr == :available_quantity and expected.specimen_type == 'Not Specified' and eval != aval then
              logger.warn("Skipped broken caTissue unspecified specimen type available comparison.")
            else
              assert(CaRuby::Resource.value_equal?(eval, aval), "#{expected.qp} was saved with #{attr} value #{eval.qp} that does not match the database value #{aval.qp}")
            end
          end
        end
      end
      verify_dependents_match(expected, actual)
    end
    
    # @param [Attribute] attr_md the saved attribute to check
    # @return [Boolean] whether the attribute is fetched, creatable and not volatile
    def verify_saved_attribute?(attr_md)
      attr_md.fetched? and attr_md.creatable? and not attr_md.volatile?
    end

    # Verifies that each expected dependent matches an actual dependent and has the same content.
    def verify_dependents_match(expected, actual)
      expected.class.dependent_attributes.each_pair do |attr, attr_md|
        # annotation query not supported
        # TODO - enable when supported
        next if attr_md.type < Annotation
        edeps = expected.database.lazy_loader.suspend { expected.send(attr) }
        next if edeps.nil_or_empty?
        adeps = actual.send(attr)
        logger.debug { "Verifying #{expected.qp} dependent #{attr} #{edeps.qp} against #{actual.qp} #{adeps.qp}..." } unless edeps.nil_or_empty?
        if attr_md.collection? then
          edeps.each do |edep|
            adep = edep.match_in_owner_scope(adeps)
            assert_not_nil(adep, "#{expected} #{attr} dependent #{edep} not found in fetched #{adeps.pp_s}")
            verify_that_saved_matches_fetched(edep, adep)
          end
        else
          edep = edeps; adep = adeps;
          assert_not_nil(adep, "#{expected} #{attr} dependent #{edep} not found in database")
          verify_that_saved_matches_fetched(edep, adep)
        end
      end
    end
  end
end
