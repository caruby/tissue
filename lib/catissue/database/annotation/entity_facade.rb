require 'singleton'
require 'caruby/import/java'
require 'caruby/database/sql_executor'
require 'catissue/database/annotation/id_generator'

module CaTissue
  module Annotation
    # EntityFacade is the caRuby substitue for the broken caTissue EntityManager. EntityManager is
    # the caTissue singleton Winnebago object for doing lots of things with dynamic extensions.
    class EntityFacade
      include Singleton
      
      # Initializes the id generator and a SQL executor. The id generator and executor are
      # used for the caTissue bug work-arounds described in the method docs and {IdGenerator}.
      def initialize
        # the work-around id generator
        @idgen = IdGenerator.new
        # a general-purpose SQL executor for calling the work-arounds
        @executor = CaTissue::Database.instance.executor
        # the primary entity class => entity id hash
        @pr_eid_hash = {}
      end

      # @param [Annotation] the annotation object
      # @return [Integer] a new identifier for the given annotation object
      def next_identifier(annotation)
        # The entity table name, which will be a cryptic value like DE_E_1283.
        eid = annotation_entity_id(annotation.class)
        aeid = common_ancestor_entity_id(eid)
        tbl = annotation_table_for_entity_id(aeid)
        next_identifier_for_table(tbl)
      end
      
      # @param [String] the table name
      # @return [Integer] the next identifier to use when creating a table record
      def next_identifier_for_table(table)
        # delegate to id generator
        @idgen.next_identifier(table)
      end
      
      # @quirk caTissue unlike the hook entity id lookup, the annotation entity id lookup strips the leading
      #   package prefix from the annotation class name. caTissue DE API requires this undocumented inconsistency.
      #
      # @quirk caTissue call into caTissue to get entity id doesn't work. caRuby uses direct SQL instead.
      #
      # @param [Class] klass the {Annotation} primary class
      # @param [Boolean] validate flag indicating whether to raise an exception if the class is not primary
      # @return [Integer] the caTissue entity id for the class
      # @raise [AnnotationError] if the validate flag is set and the class is not primary
      def annotation_entity_id(klass, validate=true)
        eid = @pr_eid_hash[klass] ||= recursive_annotation_entity_id(klass)
        if eid.nil? and validate then raise AnnotationError.new("Entity not found for annotation #{klass}") end
        eid
      end
      
      # @param [Integer] eid the entity id to check
      # @return [Boolean] whether the entity is primary
      def primary?(eid)
        result = @executor.execute { |dbh| dbh.select_one(IS_PRIMARY_SQL, eid) }
        not result.nil?
      end
      
      # @param [Class] klass the {Annotatable} class
      # @return [Integer] the class entity id
      def hook_entity_id(klass)
        result = @executor.execute { |dbh| dbh.select_one(HOOK_ENTITY_ID_SQL, klass.java_class.name) }
        if result.nil? then raise AnnotationError.new("Entity id not found for static hook class #{klass.qp}") end
        eid = result[0].to_i
        logger.debug { "Static hook class #{klass.qp} has entity id #{eid}." }
        eid
      end
      
      # @quirk caTissue call into caTissue to get entity id doesn't work for non-primary object.
      #   Furthermore, the SQL used for the #{#annotation_entity_id} doesn't work for associated annotation
      #   classes. Use alternative SQL instead.
      #
      # @param [Integer] eid the referencing entity id
      # @param [String] eid the association property name
      # @return [Integer] the referenced {Annotation} class entity id
      def associated_entity_id(eid, name)
        # The caTissue role is capitalized.
        role = name.capitalize_first
        ref_eid = recursive_associated_entity_id(eid, role)
        if ref_eid then
          logger.debug { "Entity id #{eid} is associated with property #{name} via entity id #{ref_eid}." }
        else
          logger.debug { "Entity id #{eid} is not associated with property #{name}." }
        end
        ref_eid
      end

      # @quirk caTissue Annotation classes are incorrectly mapped to entity ids, which in turn are
      #   incorrectly mapped to a table name. A candidate work-around is to bypass the caTissue DE
      #   mechanism and hit the DE Hibernate config files directly. However, the DE Hibernate mappings
      #   are incorrect and possibly no longer used. Therefore, the table must be obtained by SQL
      #   work-arounds.
      #
      # @param [Annotation] obj the annotation object
      # @return [String] the entity table name
      # @param [Integer] the annotation entity identifier
      # @return [String] the entity table name
      def annotation_table_for_entity_id(eid)
        result = @executor.execute { |dbh| dbh.select_one(TABLE_NAME_SQL, eid) }
        if result.nil? then raise AnnotationError.new("Table not found for annotation entity id #{eid}") end
        tbl = result[0]
        logger.debug { "Annotation entity with id #{eid} has table #{tbl}." }
        tbl
      end
      
      # @param (see #associated_entity_id)
      # @return [Integer, nil] the parent entity id, if any
      def parent_entity_id(eid)
        result = @executor.execute { |dbh| dbh.select_one(PARENT_ENTITY_ID_SQL, eid) }
        result[0].to_i if result and result[0]
      end
      
      # Obtains the undocumented caTisue container id for the given primary entity id.
      #
      # @quirk caTissue EntityManager.getContainerIdForEntitycontainer uses incorrect table
      #   (cf. https://cabig-kc.nci.nih.gov/Biospecimen/forums/viewtopic.php?f=19&t=421&sid=5252d951301e598eebf3e90036da43cb).
      #   The standard DE API call submits the query:
      #     SELECT IDENTIFIER FROM dyextn_container WHERE ENTITY_ID = ?
      #   This results in the error:
      #     Unknown column 'ENTITY_ID' in 'where clause'
      #   The correct SQL is as follows:
      #     SELECT IDENTIFIER FROM dyextn_container WHERE ABSTRACT_ENTITY_ID = ?
      #   The work-around is to call this SQL directly.
      #
      # @quirk caTissue in 1.2, there are deprecated primary annotations with an entity id but no container id.
      # 
      # @return [Integer] eid the primary entity id
      def container_id(eid)
        # The following call is broken (see method doc).
        # EntityManager.instance.get_container_id_for_entity(eid)
        # Work-around caTissue bug with direct query.
        result = @executor.execute { |dbh| dbh.select_one(CTR_ID_SQL, eid) }
        if result.nil? then
          logger.debug("Dynamic extension container id not found for annotation with entity id #{eid}")
          return
        end
        cid = result[0].to_i
        logger.debug { "Annotation with entity id #{eid} has container id #{cid}." }
        cid
      end
      
      private
      
      CORE_PKG_REGEX = /^edu.wustl.catissuecore.domain/
      
      CORE_GROUP = 'caTissueCore'
      
      # @param (see #annotation_entity_id)
      # @return (see #annotation_entity_id)
      def recursive_annotation_entity_id(klass)
        eid = nonrecursive_annotation_entity_id(klass) || parent_annotation_entity_id(klass)
        if eid then logger.debug { "#{klass.qp} has entity id #{eid}." } end
        eid
      end
      
      # @param (see #recursive_annotation_entity_id)
      # @return (see #recursive_annotation_entity_id)
      def nonrecursive_annotation_entity_id(klass)
        # The entity group and entity name.
        grp, name = split_annotation_entity_class_name(klass)
        # Dive into some obscure SQL.
        result = @executor.execute { |dbh| dbh.select_one(ANN_ENTITY_ID_SQL, grp, name) }
        result[0].to_i if result
      end
      
      # @param (see #nonrecursive_annotation_entity_id)
      # @return [(String, String)] the entity group name and the entity name 
      def split_annotation_entity_class_name(klass)
        # the Java class full name
        jname = klass.java_class.name
        # the Java package and base class name
        pkg, base = Java.split_class_name(jname)
        # A wustl domain class is in the core group.
        if pkg =~ CORE_PKG_REGEX then
          [CORE_GROUP, jname]
        elsif pkg.nil? or pkg['.'] then
          raise AnnotationError.new("Entity group for Java class #{jname} could not be determined.")
        else
          [pkg, base]
        end
      end
      
      # @param (see #annotation_entity_id)
      # @return (see #annotation_entity_id)
      def parent_annotation_entity_id(klass)
        nonrecursive_annotation_entity_id(klass.superclass) if klass.superclass < Annotation
      end
      
      # @param [Integer] the starting entity id
      # @return [Integer] the top-most ancestor entity id
      def common_ancestor_entity_id(eid)
        peid = parent_entity_id(eid)
        peid ? common_ancestor_entity_id(peid) : eid
      end
      
      # @param eid (see #associated_entity_id)
      # @param role the property role name
      # @return [Integer, nil] the associated entity id, if any
      def recursive_associated_entity_id(eid, role)
        nonrecursive_associated_entity_id(eid, role) or parent_associated_entity_id(eid, role)
      end
      
      # @param (see #recursive_associated_entity_id)
      # @return [Integer, nil] the associated entity id in the context of the parent, if any
      def parent_associated_entity_id(eid, role)
        peid = parent_entity_id(eid) || return
        logger.debug { "Finding  entity id #{eid} #{role} associated entity id using parent entity id #{peid}..." }
        recursive_associated_entity_id(peid, role)
      end
      
      # @param (see #recursive_associated_entity_id)
      # @return [Integer, nil] the directly associated entity id, if any
      def nonrecursive_associated_entity_id(eid, role)
        logger.debug { "Finding entity id #{eid} #{role} associated entity id..." }
        result = @executor.execute { |dbh| dbh.select_one(ASSN_ENTITY_ID_SQL, eid, role) }
        # The role role can be a mutation of the property name with spaces inserted in the
        # camel-case components, e.g. 'Additional Finding' instead of 'AdditionalFinding'.
        # TODO - fix this kludge by finding out how the role relates to the property in the
        # database.
        if result.nil? and role =~ /.+[A-Z]/ then
          alt = role.gsub(/(.)([A-Z])/, '\1 \2')
          logger.debug { "Attempting to find  entity id #{eid} #{role} associated entity id using variant #{alt}..." }
          result = @executor.execute { |dbh| dbh.select_one(ASSN_ENTITY_ID_SQL, eid, alt) }
        end
        if result.nil? and role =~ /[pP]athologic[^a]/ then
          alt = role.sub(/([pP])athologic/, '\1athological')
          logger.debug { "Attempting to find  entity id #{eid} #{role} associated entity id using variant #{alt}..." }
          result = @executor.execute { |dbh| dbh.select_one(ASSN_ENTITY_ID_SQL, eid, alt) }
        end
        if result.nil? then logger.debug { "Entity id #{eid} is not directly associated with #{role}." } end
        result[0].to_i if result
      end
      
      # The SQL to find an entity id for a primary entity.
      HOOK_ENTITY_ID_SQL = <<EOS
      select IDENTIFIER
      from DYEXTN_ABSTRACT_METADATA
      where NAME = ?
EOS
     
      # The SQL to find an entity id for a primary entity.
      ANN_ENTITY_ID_SQL = <<EOS
      select e.IDENTIFIER
      from DYEXTN_ENTITY e, DYEXTN_ABSTRACT_METADATA md, DYEXTN_ENTITY_GROUP grp
      where e.ENTITY_GROUP_ID = grp.IDENTIFIER
      and e.IDENTIFIER = md.IDENTIFIER
      and grp.SHORT_NAME = ?
      and md.NAME = ?
EOS

      # The SQL to find an entity id for an annotation reference.
      ASSN_ENTITY_ID_SQL = <<EOS
      select assn.TARGET_ENTITY_ID
      from DYEXTN_ATTRIBUTE attr, DYEXTN_ABSTRACT_ENTITY ae, DYEXTN_ASSOCIATION assn, DYEXTN_ROLE role
      where assn.IDENTIFIER = attr.IDENTIFIER
      and attr.ENTIY_ID = ae.id
      and assn.TARGET_ROLE_ID = role.IDENTIFIER
      and ae.id = ?
      and role.name = ?
EOS

      # The SQL to find an entity id for a secondary annotation referenced by a primary annotation.
      IS_PRIMARY_SQL = <<EOS
      select 1
      from DYEXTN_ABSTRACT_ENTITY ae, dyextn_entity_map map, dyextn_container ctr
      where map.CONTAINER_ID = ctr.IDENTIFIER
      and ctr.ABSTRACT_ENTITY_ID = ae.id
      and ae.id = ?
EOS

      # The SQL to find a parent entity id for a given entity id.
      PARENT_ENTITY_ID_SQL = 'select e.parent_entity_id from DYEXTN_ENTITY e where e.identifier = ?'

      # The SQL to find the database table for an entity id.
      TABLE_NAME_SQL = <<EOS
        select dp.name
        from dyextn_database_properties dp, dyextn_table_properties tp
        where dp.identifier = tp.identifier
        and tp.abstract_entity_id = ?
EOS
      
      # The caTissue DE API container id bug work-around query
      CTR_ID_SQL = "select identifier from dyextn_container where abstract_entity_id = ?"
    end
  end
end