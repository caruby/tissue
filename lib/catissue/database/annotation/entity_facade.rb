require 'singleton'
require 'caruby/import/java'
require 'caruby/database/sql_executor'
require 'catissue/database/annotation/id_generator'

module CaTissue
  module Annotation
    # Import this EntityManager dependency before EntityManager.
    java_import('edu.wustl.common.security.exceptions.UserNotAuthorizedException')
    
    # Import the caTissue Java EntityManager.
    java_import('edu.common.dynamicextensions.entitymanager.EntityManager')
   
    # EntityFacade is the caRuby interface to the caTissue EntityManager. EntityManager is
    # the caTissue singleton Winnebago object for doing lots of things with dynamic extensions.
    class EntityFacade
      include Singleton
      
      private
      
      # Initializes the caTissue EntityManager, an id generator and a SQL executor. The id
      # generator and executor are used for the caTissue bug work-arounds described in the
      # method docs and {IdGenerator}.
      def initialize
        # the encapsulated caTissue singleton
        @emgr = EntityManager.instance
        # the work-around id generator
        @idgen = IdGenerator.new
        # a general-purpose SQL executor for calling the work-arounds
        @executor = CaRuby::SQLExecutor.new(CaTissue.access_properties)
        # the primary entity class => entity id hash
        @pr_eid_hash = {}
      end
      
      public

      # @param [Annotation] the annotation object
      # @return [Integer] a new identifier for the given annotation object
      def next_identifier(annotation)
        # Commented line is broken - see IdGenerator doc.
        # EntityManager.instance.getNextIdentifierForEntity(annotation.class.name.demodulize)
        
        # The entity table name, which will be a cryptic value like DE_E_1283.
        eid = primary_entity_id(annotation.class)
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
      
      # caTissue alert - unlike the hook entity id lookup, the annotation entity id lookup strips the leading
      # package prefix from the annotation class name. caTissue DE API requires this undocumented inconsistency.
      #
      # caTissue alert - call into caTissue to get entity id doesn't work. caRuby uses direct SQL instead.
      #
      # @param [Class] klass the {Annotation} primary class
      # @param [Boolean] validate flag indicating whether to raise an exception if the class is not primary
      # @return [Integer] the caTissue entity id for the class
      # @raise [AnnotationError] if the validate flag is set and the class is not primary
      def primary_entity_id(klass, validate=true)
        eid = @pr_eid_hash[klass] ||= recursive_primary_entity_id(klass)
        if eid.nil? and validate then raise AnnotationError.new("Entity not found for annotation #{klass}") end
        eid
      end
      
      # @param [Class] klass the {Annotatable} class
      # @return [Integer] the class entity id
      def hook_entity_id(klass)
        entity_id_for_class_designator(klass.java_class.name)
      end
      
      # caTissue alert - call into caTissue to get entity id doesn't work for non-primary object.
      # Furthermore, the SQL used for the #{#primary_entity_id} doesn't work for associated annotation
      # classes. Use alternative SQL instead.
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

      # caTissue alert - Annotation classes are incorrectly mapped to entity ids, which in turn are
      # incorrectly mapped to a table name. A candidate work-around is to bypass the caTissue DE
      # mechanism and hit the DE Hibernate config files directly. However, the DE Hibernate mappings
      # are incorrect and possibly no longer used. Therefore, the table must be obtained by SQL
      # work-arounds.
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
        result[0] if result
      end
      
      # Obtains the undocumented caTisue container id for the given primary entity id.
      #
      # caTissue alert - EntityManager.getContainerIdForEntitycontainer uses incorrect table
      # (cf. https://cabig-kc.nci.nih.gov/Biospecimen/forums/viewtopic.php?f=19&t=421&sid=5252d951301e598eebf3e90036da43cb).
      # The standard DE API call submits the query:
      #   SELECT IDENTIFIER FROM dyextn_container WHERE ENTITY_ID = ?
      # This results in the error:
      #   Unknown column 'ENTITY_ID' in 'where clause'
      # The correct SQL is as follows:
      #   SELECT IDENTIFIER FROM dyextn_container WHERE ABSTRACT_ENTITY_ID = ?
      # The work-around is to call this SQL directly.
      # 
      # @return [Integer] eid the primary entity id
      # @raise [AnnotationError] if no container id is found
      def container_id(eid)
        # The following call is broken (see method doc).
        # EntityManager.instance.get_container_id_for_entity(eid)
        # Work-around caTissue bug with direct query.
        result = @executor.execute { |dbh| dbh.select_one(CTR_ID_SQL, eid) }
        cid = result[0].to_i if result
        if cid.nil? then
          raise AnnotationError.new("Dynamic extension container id not found for annotation #{annotation} with entity id #{eid}")
        end
        logger.debug { "Annotation with entity id #{eid} has container id #{cid}." }
        cid
      end
      
      private
      
      # @param (see #primary_entity_id)
      # @return (see #primary_entity_id)
      def recursive_primary_entity_id(klass)
        eid = nonrecursive_primary_entity_id(klass) || parent_primary_entity_id(klass)
        if eid then logger.debug { "#{klass.qp} has entity id #{eid}." } end
        eid
      end
      
      # @param (see #primary_entity_id)
      # @return (see #primary_entity_id)
      def nonrecursive_primary_entity_id(klass)
        # The Java class package is the entity group, the Java class unqualified name is the caption.
        pkg, cls_nm = klass.java_class.name.split('.')
        # Dive into some obscure SQL
        result = @executor.execute { |dbh| dbh.select_one(CTR_ENTITY_ID_SQL, pkg, cls_nm) }
        result[0] if result
      end
      
      # @param (see #primary_entity_id)
      # @return (see #primary_entity_id)
      def parent_primary_entity_id(klass)
        nonrecursive_primary_entity_id(klass.superclass) if klass.superclass < Annotation
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
      # @return @return [Integer, nil] the directly associated entity id, if any
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
        if result.nil? then
          logger.debug { "Entity id #{eid} is not directly associated with #{role}." }
        end
        result[0] if result
      end
      
      # @param [String] designator the class name, demodulized in the case of an annotation entity
      # @return [Integer] the caTissue entity id for the given class name
      # @raise [CaRuby::DatabaseError] if the DE entity id is not found for the given designator
      def entity_id_for_class_designator(designator)
        @emgr.getEntityId(designator) or
          raise CaRuby::DatabaseError.new("Dynamic extension entity id not found for #{designator}")
      end
      
      # The SQL to find an entity id for a primary entity.
      CTR_ENTITY_ID_SQL = <<EOS
      select ctr.ABSTRACT_ENTITY_ID
      from DYEXTN_CONTAINER ctr, DYEXTN_ENTITY_GROUP grp
      where ctr.ENTITY_GROUP_ID = grp.IDENTIFIER
      and grp.SHORT_NAME = ?
      and ctr.CAPTION = ?
EOS

      # The SQL to find an entity id for a secondary annotation referenced by a primary annotation.
      ASSN_ENTITY_ID_SQL = <<EOS
      select assn.TARGET_ENTITY_ID
      from DYEXTN_ATTRIBUTE attr, DYEXTN_ABSTRACT_ENTITY ae, DYEXTN_ASSOCIATION assn, DYEXTN_ROLE role
      where assn.IDENTIFIER = attr.IDENTIFIER
      and attr.ENTIY_ID = ae.id
      and assn.TARGET_ROLE_ID = role.IDENTIFIER
      and ae.id = ?
      and role.name = ?
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