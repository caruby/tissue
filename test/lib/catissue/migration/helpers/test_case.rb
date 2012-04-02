require File.dirname(__FILE__) + '/../../../../helpers/test_case'
require 'jinx/helpers/uniquifier'
require 'catissue/migration/migrator'

module CaTissue
  module MigrationTestCase
    include CaTissue::TestCase

    #@param [String] fixtures the fixtures directory
    def setup(fixtures)
      super()
      @fixtures = fixtures
      # Clear the uniquifier for this migration.
      Jinx::Uniquifier.instance.clear
    end

    private

    # @group Migration test utility methods

    # Runs a migrator on the given input fixture and options.
    #
    # @param (see #create_migrator)
    # @option (see #create_migrator)
    # @yield [obj] verify the migration
    # @yieldparam [Resource] obj the migrated object
    def migrate_to_database(fixture, opts={})
      mgtr = create_migrator(fixture, opts)
      logger.debug { "Migration test migrating #{fixture} fixture..." }
      mgtr.migrate_to_database do |tgt, rec|
        @post_pcsr.call(tgt) if @post_pcsr
        yield tgt if block_given?
      end
      logger.debug { "Migration test migrated #{fixture} fixture." }
    end

    # Creates a new Migrator for the given fixture with the given options.
    # If a factory block is provided, then that factory is called to make a new
    # Migrator instance. Otherwise, {CaTissue::Migrator#initialize} makes the instance.
    #
    # If there is no +:input+ option, then the migration input is set to the
    # _fixture_.+csv+ file in the {#initialize} fixtures directory.
    #
    # @param [Symbol] fixture the migration test fixture
    # @param [{Symbol => Object}] opts (see CaTissue::Migrator#initialize)
    # @option (see CaTissue::Migrator#initialize)
    # @yield [obj] post-process the migrated object
    # @yieldparam [Resource] obj the migrated object
    # @return [CaTissue::Migrator]
    def create_migrator(fixture, opts={}, &block)
      opts[:input] ||= File.expand_path("#{fixture}.csv", @fixtures)
      @post_pcsr = block if block_given?
      CaTissue::Migrator.new(opts)
    end

    # Verifies that the given test fixture is successfully migrated.
    # Each migrated target object is validated using {CaTissue::TestCase#verify_saved}.
    # In addition, if a verifier block is given to this method, then that block is
    # called on the target migration object, or nil if no target was migrated.
    # Supported options are described in +Jinx::Migrator.migrate+.
    #
    # @param (see #verify_target)
    # @option (see #verify_target)
    # @yield (see #verify_target)
    # @yieldparam (see #verify_target)
    def verify_save(fixture, opts={})
      logger.debug { "Migrating the #{fixture} test fixture..." }
      opts[:unique] = true unless opts.has_key?(:unique)
      migrate_to_database(fixture, opts) do |tgt, rec|
        @post_pcsr.call(tgt) if @post_pcsr
        verify_saved(tgt)
        yield tgt if block_given?
      end
    end

    # Verifies the given fixture migration.
    # Each migrated target object is validated using {#validate_target}.
    # The target is migrated but not stored.
    # The +:unique+ option is set to false by default.
    #
    # @param [Symbol] fixture the test fixture to verify
    # @param [<Symbol>] opts the migration options
    # @option (see CaTissue::Migrator#migrate)
    # @yield [target] verifies the given target
    # @yieldparam [Resource] target the domain object to verify
    def verify_target(fixture, opts={}, &verifier)
      opts[:unique] ||= false
      create_migrator(fixture, opts).migrate do |tgt, rec|
        @post_pcsr.call(tgt) if @post_pcsr
        validate_target(tgt, &verifier)
      end
    end

    # Validates that the given target was successfully migrated.
    # If a target was migrated, then this method calls {CaTissue::TestCase#verify_defaults}
    # to confirm that the target can be stored.
    # In addition, if a block is given to this method then the block is called on the
    # (possibly nil) migration target.
    #
    # @param [Resource] target the domain object to verify
    # @yield (see #verify_target)
    # @yieldparam (see #verify_target)
    def validate_target(target)
      assert_not_nil(target, "Missing target")
      logger.debug { "Validating migration target #{target}..." }
      verify_defaults(target) unless target.identifier
      yield target if block_given?
      logger.debug { "Validated migration target #{target}." }
      target
    end
  end
end
