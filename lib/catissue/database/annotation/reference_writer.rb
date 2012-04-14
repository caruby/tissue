module CaTissue
  module Annotation
    # A ReferenceWriter saves annotations to the database. This is a helper class to work around
    # caTissue DE API defects. This class infers a direct data mapping by navigating the caTissue
    # DYEXT tables of the introspected Java annotation class properties.
    class ReferenceWriter
      # @param [Integer] eid the referencing annotation entity id
      # @param [Jinx::Property] prop the annotation attribute metadata of the attribute to save
      # @param [Integer, nil] assn_eid the referenced annotation entity id
      def initialize(eid, prop, assn_eid=nil)
        logger.debug { "Mapping annotation #{prop.declarer.qp}.#{prop} role attributes to database columns..." }
        efcd = EntityFacade.instance
        # the referenced annotation entity id
        assn_eid ||= associated_entity_id(eid, prop)
        # the referenced entity database table
        @table = efcd.annotation_table_for_entity_id(assn_eid)
        # map the attribute => column
        attr_col_hash = map_attributes(prop.type, assn_eid)
        logger.debug { "Annotation #{prop.declarer.qp} #{prop} reference type #{prop.type.qp} maps to #{@table} as #{attr_col_hash.qp}" }
        # the mapped attributes and columns
        @attributes, cols = attr_col_hash.to_a.transpose
        # the SQL parameters clause
        params = Array.new(cols.size, '?').join(', ')
        # the create SQL
        @cr_sql = CREATE_SQL % [@table, cols.join(', '), params]
        # the update SQL
        @upd_sql = UPDATE_SQL % [@table, cols.map { |col| "#{col} = ?" }.join(', ')]
        # the superclass writer for annotations with superclass DE forms
        @parent = obtain_parent_writer(eid, prop)
      end
      
      # @param [Annotation] annotation the referenced annotation value
      def save(annotation)
        # select the SQL based on whether this is an update or a create
        sql = annotation.identifier ? @upd_sql : @cr_sql
        # allocate a new database identifier
        annotation.identifier ||= next_identifier
        # the values to bind to the SQL parameters
        values = database_parameters(annotation)
        logger.debug { "Saving annotation #{annotation} to #{@table}..." }
        # dispatch the SQL update or create statement
        Database.instance.executor.transact(sql, *values)
        # Save the superclass attributes.
        if @parent then
          logger.debug { "Saving #{annotation} parent entity attributes..." }
          @parent.save(annotation)
        end
      end
      
      protected
      
      # @return [Integer] the identifier to use when creating a new annotation instance
      def next_identifier
        @parent ? @parent.next_identifier : EntityFacade.instance.next_identifier_for_table(@table)
      end
      
      private
      
      # @param (see #initialize)
      # @return [Integer] the entity id for the given attribute role
      # @raise [AnnotationError] if the associated entity was not found
      def associated_entity_id(eid, prop)
        EntityFacade.instance.associated_entity_id(eid, prop.property_descriptor.name) or
          raise AnnotationError.new("Associated entity not found for entity #{eid} attribute #{prop}")
      end      
      
      # @param (see #initialize)
      # @return [Integer, nil] the superclass associated entity id for the given attribute role, or nil if none
      def obtain_parent_writer(eid, prop)
        # the superclass entity id for annotations with superclass DE forms
        peid = EntityFacade.instance.parent_entity_id(eid) || return
        # the associated entity id
        aeid = EntityFacade.instance.associated_entity_id(peid, prop.property_descriptor.name)
        ReferenceWriter.new(peid, prop, aeid) if aeid
      end
      
      # @param annotation (see #save)
      # @return [Array] the save SQL call parameters 
      def database_parameters(annotation)
        @attributes.map do |pa|
          value = annotation.send(pa)
          Annotation === value ? value.identifier : value
        end
      end
      
      def map_attributes(klass, eid)
        # Fill in the attribute => column hash for non-domain attributes.
        ach = klass.nondomain_attributes.to_compact_hash do |pas|
          nondomain_attribute_column(klass, pas, eid)
        end
        # Add the owner attribute => column entries.
        klass.owner_attributes.each do |oattr|
          ach[oattr] = owner_attribute_column(klass, oattr, eid)
        end
        ach
      end
      
      def nondomain_attribute_column(klass, attribute, eid)
        return IDENTIFIER_COL if attribute == :identifier
        prop = klass.property(attribute)
        # skip an attribute declared by the superclass
        return unless prop.declarer == klass
        prop = prop.property_descriptor.name
        logger.debug { "Finding #{klass.qp} #{attribute} column for entity id #{eid} and property #{prop}..." }
        result = Database.instance.executor.query(NONDOMAIN_COLUMN_SQL, prop, eid).first
        col = result[0] if result
        if col.nil? then
          raise AnnotationError.new("Column not found for #{klass.qp} #{attribute}")
        end
        col
      end
      
      # @quirk caTissue The caTissue 1.1.2 DYNEXT_ROLE table omits the target name for seven annotations,
      #   e.g. SCG RadicalProstatectomyMargin. Work-around is to try the query with a null role name.
      #
      # @quirk caTissue The role can be a mutation of the demodulized class name as follows:
      #   * decapitalization, e.g. role +specimenCollectionGroup+ for class +SpecimenCollectionGroup+
      #
      # @param [Metadata] klass the annotation class
      # @param [Symbol] attribute the owner attribute
      # @param [Integer] eid the annotation entity id
      # @return [String] the owner reference SQL column name
      def owner_attribute_column(klass, attribute, eid)
        logger.debug { "Finding #{klass.qp} #{attribute} column in the context of entity id #{eid}..." }
        # The referenced class name (confusingly called a source role in the caTissue schema).
        tgt_nm = klass.property(attribute).type.name.demodulize
        result = Database.instance.executor.query(OWNER_COLUMN_SQL, eid, tgt_nm).first
        col = result[0] if result
        if col.nil? then
          result = Database.instance.executor.query(OWNER_COLUMN_SQL, eid, tgt_nm.decapitalize).first
          col = result[0] if result
        end
        if col.nil? then
          result = Database.instance.executor.query(ALT_1_1_OWNER_COLUMN_SQL, eid).first
          col = result[0] if result
        end
        if col.nil? then raise AnnotationError.new("Column not found for #{klass.qp} owner attribute #{attribute}") end
        col
      end
      
      IDENTIFIER_COL = 'IDENTIFIER'
      
      # Generic update template.
      UPDATE_SQL = "update %s set ACTIVITY_STATUS = 'Active', %s"
      
      # Generic create template.
      CREATE_SQL = "insert into %s(ACTIVITY_STATUS, %s)\nvalues ('Active', %s)"
      
      # SQL to get the primitive column name for a given annotation class entity id and Java property name
      NONDOMAIN_COLUMN_SQL = <<EOS
        select dbp.name
        from DYEXTN_ABSTRACT_METADATA amd, DYEXTN_CONTROL ctl, DYEXTN_CONTAINER ctr, DYEXTN_DATABASE_PROPERTIES dbp, DYEXTN_COLUMN_PROPERTIES cp
        where amd.NAME = ?
        and ctl.CONTAINER_ID = ctr.IDENTIFIER
        and amd.IDENTIFIER = ctl.BASE_ABST_ATR_ID
        and ctl.BASE_ABST_ATR_ID = cp.PRIMITIVE_ATTRIBUTE_ID
        and dbp.IDENTIFIER = cp.IDENTIFIER
        and ctr.ABSTRACT_ENTITY_ID = ?
EOS
      
      # SQL to get the annotation reference column name for a given annotation target entity id.
      # The target entity id is obtained by calling {EntityFacade#associated_entity_id}.
      OWNER_COLUMN_SQL = <<EOS
        select cst.TARGET_ENTITY_KEY
        from DYEXTN_CONSTRAINT_PROPERTIES cst, DYEXTN_ASSOCIATION assn, dyextn_role role
        where cst.ASSOCIATION_ID = assn.IDENTIFIER
        and assn.SOURCE_ROLE_ID = role.IDENTIFIER
        and assn.TARGET_ENTITY_ID = ?
        and role.name = ?
EOS
      
      # Alternative caTissue 1.1.x SQL to get the annotation reference column name for a given
      # annotation target entity id. The role can be null for some entities in 1.1, as described
      # in {#owner_attribute_column}. The target entity id is obtained by calling
      # {EntityFacade#associated_entity_id}.
      ALT_1_1_OWNER_COLUMN_SQL = <<EOS
        select cst.TARGET_ENTITY_KEY
        from DYEXTN_CONSTRAINT_PROPERTIES cst, DYEXTN_ASSOCIATION assn, dyextn_role role
        where cst.ASSOCIATION_ID = assn.IDENTIFIER
        and assn.SOURCE_ROLE_ID = role.IDENTIFIER
        and assn.TARGET_ENTITY_ID = ?
        and role.name IS NULL
EOS
    end
  end
end
