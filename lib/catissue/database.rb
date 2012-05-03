require 'jinx/helpers/validation'
require 'jinx/helpers/uniquifier'
require 'caruby/database'
require 'catissue/database/annotation/annotator'
require 'catissue/helpers/collectible_event_parameters'
require 'catissue/helpers/collectible'

module CaTissue
  # +CaTissue::Database+ mediates access to the caTissue application service and database.
  # The +CaRuby::Database+ functionality is preserved, but +CaTissue::Database+ overrides
  # several base class private methods to enable alternate CaTissue-specific search strategies
  # and work around caTissue and caCORE bugs.
  #
  # There is a single caTissue client database instance per thread. 
  #
  # This class contains a grab-bag of long and convoluted method implementations for the
  # many caTissue API quirks that necessitate special attention.
  class Database < CaRuby::Database
    def self.current
      Thread.current[:crtdb] ||= new 
    end
    
    # Creates a new Database with the +catissuecore+ service and {#access_properties}.
    def initialize
      super(SVC_NAME) { access_properties }
    end
    
    # @return (see CaRuby::Domain.properties)
    def access_properties
      CaTissue.properties
    end
    
    # return [CaRuby::SQLExecutor] a utility SQL executor
    def executor
      @executor ||= create_executor
    end

    # @return [Annotator] the annotator utility
    def annotator
      @annotator ||= Annotator.new(self)
    end

    # If the given domain object is an {Annotation}, then this method returns the +CaRuby::AnnotationService+
    # for the object {AnnotationModule}, otherwise this method returns the standard {CaTissue::Database}
    # service.
    #
    # @param (see CaRuby::Database#persistence_service)
    # @return (see CaRuby::Database#persistence_service)
    def persistence_service(klass)
      klass < Annotation ? klass.annotation_module.persistence_service : super
    end
    
    # @quirk caTissue caTissue Address create succeeds but does not set the result identifier, rendering
    #   the result useless. This leads to obscure cascading errors if the address is saved before
    #   creating and then updating the address owner. Throw an exception if the create argument is an
    #   address. An address can be created but only in the context of its owner, and special case logic
    #   is required to fetch the address by an inverted query on the owner address reference.
    #
    # @param [Resource] obj the dependent domain object to save
    # @raise [CaRuby::DatabaseError] if the object is a {CaTissue::Address}
    def create(obj)
      if CaTissue::Address === obj then
        raise CaRuby::DatabaseError.new("Address creation is not supported.new(since a caTissue bug does not set the create result identifier property.")
      end
      super
    end
    
    # Augments +CaRuby::Database.ensure_exists} to ensure that an {Annotation::Proxy+ reference identifier
    # reflects the hook identifier.
    #
    # @param (see CaRuby::Database::Writer#ensure_exists)
    def ensure_exists(obj)
      if Annotation::Proxy === obj then
        obj.ensure_hook_exists
      end
      super
    end
    
    private

    # The application service name.
    SVC_NAME = 'catissuecore'
    
    UPD_EID_SQL = 'update catissue_external_identifier set name = ?, value = ?, specimen_id = ? where identifier = ?'
    
    UPD_CTR_SQL = 'update catissue_consent_tier_response set response = ? where identifier = ?'
    
    MAX_ADDR_ID_SQL = "select max(identifier) from catissue_address"
    
    # @quirk caTissue The database connection properties cannot be inferred from the caTissue
    #   +HibernateUtil+ class. The class is found, but class load results in the following error:
    #     NameError: cannot initialize Java class edu.wustl.common.hibernate.HibernateUtil
    #   This error is probably due to the arcane caTissue static initializer dependencies.
    #
    # return (see #executor)
    def create_executor
      # Augment the user-defined application properties with Hibernate properties.
      props = access_properties
      hprops = Java::edu.wustl.common.hibernate.HibernateUtil.configuration.properties.to_hash rescue nil
      if hprops then
        props[:database_user] ||= hprops['connection.username']
        props[:database_password] ||= hprops['connection.password']
        if not props.has_key?(:database_name) and not props.has_key?(:database_port) and hprops.has_key?('connection.url') then
          props[:database_url] ||= hprops['connection.url']
        end
        props[:database_driver_class] ||= hprops['connection.driver_class']
      end
      CaRuby::SQLExecutor.new(props)
    end

    # Overrides #+CaRuby::Database::Writer.recursive_save?+ to support the update work-around
    # described in {#update_object}. A recursive SCG update is allowed if the nested
    # transaction sequence is:
    # * Update SCG
    # * Update SCG event parameters as part of Update SCG
    # * Update SCG as part of the Bug #135 work-around
    #
    # @param (see CaRuby::Database::Writer#recursive_save?)
    # @return (see CaRuby::Database::Writer#recursive_save?)
    def recursive_save?(obj, operation)
      super and not collectible_event_update_workaround?(obj, operation)
    end
    
    # Returns whether the given specimens are compatible. The target is compatible with the source
    # if each of the following conditions hold:
    # * The specimen types are equal or the source specimen type is +Not Specified+
    # * The specimen pathological statuses are equal or the source pathological status is +Not Specified+
    # * The parent specimens are compatible, if they exist
    #
    # @param [Resource] target the mnerge target specimen
    # @param [Resource] source the mnerge source specimen
    # @return [Boolean] whether the specimens are compatible
    def specimen_compatible?(target, source)
      target.class === source and
      specimen_parent_compatible?(target, source) and
      (target.specimen_type == source.specimen_type or source.specimen_type == 'Not Specified') and
      (target.pathological_status == source.pathological_status or source.pathological_status == 'Not Specified')
    end

    # @see #specimen_compatible?
    def specimen_parent_compatible?(target, source)
      if target.parent then
        source.parent and source.parent.identifier == target.parent.identifier
      else
        source.parent.nil?
      end
    end

    # This method patches up fetched sources to correct the following anomaly:
    #
    # @quirk caCORE fetched references are not reconciled within an existing query result, e.g.
    #   given a query result with two Specimens s1 and s2, the parent reference is not fetched.
    #   Subsequently fetching the parent is independent of the query result. Thus if s1 is the parent
    #   of s2 in the database, the fetched s2 parent s3 is distinct from s1, even though
    #   s1.identifier == s3.identifier. Thus, enforcing reference consistency requires a post-fetch step
    #   that matches the fetched objects to the original query result on identifier and resets the
    #   references.
    #
    # Not yet enabled. TODO - plug this into fetch_object.
    #
    # @param [<Resource>] refs the fetched domain objects
    # @param [Symbol] attribute the owner attribute
    def resolve_parent(refs, attribute)
      id_ref_hash = refs.to_compact_hash { |ref| ref.identifier }.invert
      refs.each do |ref|
        parent = ref.send(attribute) || next
        resolved = id_ref_hash[parent.identifier] || next
        logger.debug { "Resetting #{ref.qp} #{attribute} from #{parent} to #{resolved} in order to fix a caCORE inconsistency..." }
        ref.set_property_value(attribute, resolved)
      end
    end

    # @quirk caTissue Bug #135: Update SCG SpecimenEventParameters raises AuditException.
    #   Work around is to update the SCG instead.
    #
    # @quirk caTissue CPR consent tier response update results in 'Access denied' error.
    #   Work-around is to update the response using a direct SQL call.
    #
    # @quirk caTissue The label is auto-generated by caTissue when the specimen is created.
    #   Label creation depends on an auto-generator. Therefore, the specimen must be refetched
    #   when collected in order to reflect the database label value.
    #
    # @quirk caTissue The Specimen label is auto-generated when the collection status is changed
    #   from Pending to Collected. However, the update argument label is not updated to reflect
    #   the auto-generated value. Note that the barcode is auto-generated on create, not update.
    #
    # @quirk caTissue Updating a User does not cascade update to the address.
    #   address is cascade none in Hibernate, but is created in caTissue, perhaps by biz logic.
    #   An address change is ignored by the User update. Since Address cannot be updated
    #   separately due to a different caTissue bug, the address update must be performed
    #   by a work-around here.
    #
    # @quirk caTissue Specimen update does not cascade to a referenced SpecimenEventParameters.
    #   Even though the reference property is marked cascade in Hibernate, the update does
    #   not propagate to the SpecimenEventParameters. Specimen create does cascade. SCG update
    #   cascades. Certain SpecimenEventParameters subclasses have variant Specimen cascade
    #   behavior, as described in other quirk documentation. The work-around is to update
    #   the Specimen SpecimenEventParameters directly rather than delegating the update
    #   to the Specimen owner.
    #
    # @quirk caTissue caTissue Specimen update ignores the available quantity. Unlike the
    #   auto-generated Specimen update, there is no known work-around
    #
    # @param (see CaRuby::Database#update_object)
    def update_object(obj)
      # prep work
      case obj
      when CaTissue::SpecimenCollectionGroup then
        if obj.collection_protocol_registration.nil? then
          # add the extraneous SCG template CPR
          logger.debug { "Work around caTissue bug by fetching extraneous #{obj} CPR..." }
          obj.collection_protocol_registration = fetch_association(obj, :collection_protocol_registration)
        end
        if obj.collection_status.nil? and obj.collection_event_parameters then
          obj.collection_status = 'Complete'
          logger.debug { "Set #{obj} status to Complete since it has collection event parameters." }
        end
      when CaTissue::Specimen then
        prepare_specimen_for_update(obj)
      when CaTissue::StorageContainer then
        if obj.storage_type.nil? then
          logger.debug { "Fetching #{obj} storage type prior to update..." }
          lazy_loader.enable { obj.storage_type }
        end
      end
      
      # Delegate update special cases.
      if CaTissue::User === obj then
        if obj.address.identifier.nil? or obj.address.changed? then
          return update_user_address(obj, obj.address)
        end
      end
      if CollectibleEventParameters === obj then
        if obj.specimen_collection_group then
          return save_collectible_scg_event_parameters(obj)
        elsif obj.specimen then
          return update_from_template(obj)
        end
      elsif SpecimenEventParameters === obj then
        return update_from_template(obj)
      elsif CaTissue::ConsentTierResponse === obj then
        return update_consent_tier_response(obj)
      elsif Annotation === obj then
        raise CaRuby::DatabaseError.new("Annotation update is not supported on #{obj}")
      end
      
      # Finally, the standard update.
      super
    end
    
    # Updates the given dependent.
    #
    # @quirk caTissue 1.2 user address update results in authorization error. Work-around is to
    #   create a new address record.
    #
    # @quirk caTissue Specimen update cascades to child update according to Hibernate, but
    #   caTissue somehow circumvents the child update. The child database content is not changed
    #   to reflect the update argument. Work-around is to update the child independently after
    #   the parent update.
    #
    # @quirk caTissue The aforementioned {#save_with_template} caTissue collectible event parameters
    #   dependent bug implies that the dependent must be saved directly rather than via a cascade
    #   from the Specimen or SCG owner to the referenced event parameters. The direct save avoids
    #   a tangled nest of obscure caTissue bugs described in the {#save_with_template} rubydoc.
    #
    # @param (see CaRuby::Writer#update_changed_dependent)
    def update_changed_dependent(owner, property, dependent, autogenerated)
      # Save the changed collectible event parameters directly rather than via a cascade.
      if CollectibleEventParameters === dependent then
        logger.debug { "Work around a caTissue bug by resaving the collected #{owner} #{dependent} directly rather than via a cascade..." }
        return update_from_template(dependent)
      end
      if CaTissue::User === owner and property.attribute == :address then
        update_user_address(owner, dependent)
      elsif CaTissue::Specimen === owner and CaTissue::Specimen === dependent then
        logger.debug { "Work around caTissue bug to update #{dependent} separately after the parent #{owner} update..." }
        prepare_specimen_for_update(dependent)
        update_from_template(dependent)
        logger.debug { "Updated the #{owner} child #{dependent}." }
      else
        super
      end
    end
  
    def prepare_specimen_for_update(obj)
      if obj.collection_status.nil? and obj.collection_event_parameters then
        obj.collection_status = 'Collected'
        logger.debug { "Set #{obj} status to Collected since it has collection event parameters." }
      end
      if obj.characteristics.nil? then
        logger.debug { "Fetching #{obj} characteristics for update..." }
        fetched = fetch_association(obj, :specimen_characteristics)
        raise CaRuby::DatabaseError.new("#{obj} is missing characteristics") if fetched.nil?
        logger.debug { "Set #{obj} characteristics to #{fetched}." }
        obj.characteristics = fetched
      elsif obj.characteristics.identifier.nil? then
        logger.debug { "Fetching #{obj} characteristics identifier for update..." }
        fetched = fetch_association(obj, :specimen_characteristics)
        raise raise CaRuby::DatabaseError.new("#{obj} is missing characteristics") if fetched.nil?
        obj.characteristics.identifier = fetched.identifier
        logger.debug { "Set #{obj} characteristics #{obj.characteristics} identifier." }
      end
      cep = obj.collection_event_parameters
      rep = obj.received_event_parameters
      if (cep and cep.identifier.nil?) or (rep and rep.identifier.nil?) then
        logger.debug { "Fetching #{obj} collectible event parameters identifiers for update..." }
        eps = fetch_association(obj, :specimen_event_parameters)
        fcep = eps.detect { |ep| CaTissue::CollectionEventParameters === ep }
        if fcep then
          cep.merge(fcep)
          logger.debug { "Set #{obj} #{cep} identifier." }
        end
        frep = eps.detect { |ep| CaTissue::ReceivedEventParameters === ep }
        if frep then
          rep.merge(frep)
          logger.debug { "Set #{obj} #{rep} identifier." }
        end
      end
      # A collected specimen requires a label.
      if obj.collection_status == 'Collected' and  obj.label.nil? then
        obj.label = Jinx::Uniquifier.qualifier
        logger.debug { "Worked around caTissue bug by setting a collected specimen label to #{obj.label}." }
      end
    end
    
    # Updates the given user address.
    #
    # @param [CaTissue::User] the user owner
    # @param [CaTissue::Address] the address to update
    # @return [CaTissue::User] the updated user
    def update_user_address(user, address)
      logger.debug { "Work around caTissue prohibition of #{user} address #{address} update by creating a new address record for a dummy user..." }
      address.identifier = nil
      perform(:create, address) { create_object(address) }
      logger.debug { "Worked around caTissue address update bug by swizzling the #{user} address #{address} identifier." }
      perform(:update, user) { update_object(user) }
      user
    end
    
    # Returns whether operation is the second Update described in {#recursive_save?}.
    def collectible_event_update_workaround?(obj, operation)
      # Is this an update?
      return false unless Collectible === obj and operation == :update
      last = @operations.last
      # Is there a nesting operation?
      return false unless last
      # Is the nesting operation subject a CEP?
      return false unless CaTissue::CollectibleEventParameters === last.subject
      # Is the nesting operation subject owned by the current object?
      return false unless last.subject.owner == obj
      prev = penultimate_save_operation
      # Is the outer save operation subject the current object?
      prev and prev.subject == obj
    end
    
    def penultimate_save_operation
      2.upto(@operations.size) do |index|
        op = @operations[-index]
        return op if op.save?
      end
      nil
    end
    
    # Adds the specimen position to its save template.
    #
    # @param [CaTissue::Specimen] specimen the existing specimen with an existing position
    # @param template (see #save_with_template) 
    # @see {#save_with_template}
    def add_position_to_specimen_template(specimen, template)
      pos = specimen.position
      # the non-domain position attributes
      pas = pos.class.nondomain_attributes
      # the template position reflects the old values, if available
      ss = pos.snapshot
      # the attribute => value hash
      vh = ss ? pas.to_compact_hash { |pas| ss[pas] } : pos.value_hash(pas)
      vh[:specimen] = template
      vh[:storage_container] = pos.storage_container.copy
      # the template position reflects the old values
      template.position = pos.class.new(vh)
      logger.debug { "Work around #{specimen} update anomaly by copying position #{template.position.qp} to update template #{template.qp} as #{template.position.qp} with values #{vh.qp}..." }
    end

    # @param [CollectibleEventParameters] ep the SCG event parameters to save
    # @return (see #update_object)
    # @see #create_object
    # @see #update_object
    def save_collectible_scg_event_parameters(ep)
      scg = ep.specimen_collection_group
      logger.debug { "Work around #{ep.qp} caTissue SCG event parameters save bug by updating the owner #{scg.qp} instead..." }
      if ep.identifier.nil? then
        ensure_exists(scg)
        return ep if ep.identifier
      end
      update_from_template(scg)
      # Last resort: straight create; probably will fail due to caTissue bug which
      # expects a CEP create to reference a specimen rather than a SCG.
      create_from_template(ep) if ep.identifier.nil?
      ep
    end
    
    
    # @param [CaTissue::ConsentTierResponse] ctr the response to update
    # @see #update_object
    def update_consent_tier_response(ctr)
        # Call the SQL
        logger.debug { "Work around caTissue #{ctr} update bug by submitting direct SQL call..." }
        executor.transact(UPD_CTR_SQL, ctr.response, ctr.identifier)
        logger.debug { "caTissue #{ctr} update work-around completed." }
    end

    # Overrides +CaRuby::Database::Writer.save_changed_dependents+ to handle the following anomaly:
    #
    # @quirk caTissue DisposalEventParameters must be created after all other Specimen SEPs. This
    #   use case arises when migrating a source biorepository discarded specimen for archival.
    #   
    #   The process for creating a discarded Specimen is as follows:
    #   * Create the Specimen with status Active.
    #   * Create the non-disposal events.
    #   * Create the DisposalEventParameters.
    #   
    #   {#save_changed_dependents} delegates to this method to handle the latter two steps.
    #   
    #   A DisposalEventParameters cannot be created for a closed Specimen. Conversely, caTissue closes
    #   the Specimen as a side-effect of creating a DisposalEventParameters. Therefore, even if the
    #   client submits a closed Specimen for create, this CaTissue::Database must first create the
    #   Specimen with status Active, then submit the DisposalEventParameters.
    #   
    #   This is a work-around on top of the {#create_unavailable_specimen} work-around. See that method 
    #   for the subtle interaction required between these two work-arounds.
    #
    # @param (see CaRuby::Writer#save_dependents)
    def save_changed_dependents(obj)
      if CaTissue::Specimen === obj then
        dsp = obj.specimen_events.detect { |ep| CaTissue::DisposalEventParameters === ep }
      end
      if dsp then
        obj.specimen_events.delete(dsp)
        logger.debug { "Work around a caTissue #{obj.qp} event parameters save order dependency by deferring the #{dsp.qp} save..." }
        obj.specimen_events.delete(dsp)
      end
      
      # Delegate to the standard save_changed_dependents.
      begin
        super
      ensure
        obj.specimen_events << dsp if dsp
      end
      
      # Save the deferred disposal, if any.
      if dsp then
        logger.debug { "Creating deferred #{obj.qp} dependent #{dsp.qp}..." }
        save_dependent_if_changed(obj, :specimen_events, dsp)
        if obj.activity_status != 'Closed' then
          logger.debug { "Refetching the disposed #{obj.qp} to reflect the modified activity status..." }
          obj.activity_status = nil
          obj.find
        end
      end
    end
    
    # Overrides +CaRuby::Database.build_save_template+ to return obj itself if
    # obj is an {Annotation}, since annotations do not employ a separate template.
    #
    # @param (see CaRuby::Database#build_save_template)
    # @return (see CaRuby::Database#build_save_template)
    def build_save_template(obj, builder)
      Annotation === obj ? prepare_annotation_as_save_template(obj) : super
    end
    
    # Validates and completes the given annotation object prior to save.
    # The annotation is submitted directly to the caTissue save rather
    # than building a save template, since an annotation save does not
    # recurse to references, unlike a standard save.
    #
    # @param [Annotation] annotation the object to create
    # @return [Annotation] the annotation object
    # @raise (see #ensure_primary_annotation_has_hook)
    def prepare_annotation_as_save_template(annotation)
      ensure_primary_annotation_has_hook(annotation) if annotation.class.primary?
      annotation
    end
    
    # Ensures that a primary annotation hook exists.
    #
    # @param (see #prepare_annotation_for_save)
    # @raise [CaRuby::DatabaseError] if the annotation does not reference a hook entity
    def ensure_primary_annotation_has_hook(annotation)
      hook = annotation.hook
      if hook.nil? then
        raise CaRuby::DatabaseError.new("Cannot save annotation #{annotation} since it does not reference a hook entity")
      end
      if hook.identifier.nil? then
        logger.debug { "Ensuring that the annotation #{annotation.qp} hook entity #{hook.qp} exists in the database..." }
        ensure_exists(hook)
      end
    end

    # Augments +CaRuby::Database.save_with_template+ to work around the following caTissue anomalies:
    #
    # @quirk caTissue Bug #149: API update TissueSpecimen position validation incorrect.
    #   The Specimen update argument must reference the old position, even though the position is not
    #   updatable, unless old status is Pending. The validation defect described in Bug #149 requires
    #   a work-around that is also used for a different reason described in the following paragraph.
    #
    # @quirk caTissue Update of a {CaTissue::Specimen} which references a position must include the former
    #   position in the caTissue service update argument. A Specimen position is altered as a side-effect
    #   by creating a proxy save {CaTissue::TransferEventParameters}. The changed position is not reflected
    #   in the Specimen position, which must be refetched to reflect the database state. This fetch is
    #   done automatically by +CaRuby::Database+ as part of the save proxy mechanism. The Specimen update
    #   template must include a reference to the former position but not the changed position.
    #
    #   However, the Specimen +CaRuby::Writer.update+ argument will include the changed position, not the
    #   former position. The template built by +CaRuby::Writer.update+ for submission to the caTissue app
    #   does not include a position reference, since the position has a save proxy which handles position
    #   change as part of the +CaRuby::Writer+ update dependent propagation.
    #
    #   Thus, updating a Specimen which includes a position change is performed as follows:
    #   * reconstitute the former position from the Position snapshot taken as part of the
    #      +CaRuby::Persistable+ change tracker.
    #   * add the former position to the template (which will now differ from the +CaRuby::Writer.update+
    #     argument).
    #   * submit the adjusted Specimen template to the caTissue app updateObject.
    #   * +CaRuby::Writer.update+ will propagate the Specimen update to the changed position dependent,
    #     which in turn saves via the {CaTissue::TransferEventParameters} proxy.
    #   * The proxy save will in turn refetch the proxied Specimen position to obtain the identifier
    #     and merge this into the Specimen position.
    #   * The Specimen update template is used solely to satisfy the often arcane caTissue interaction
    #     requirements like this work-around, and is thrown away along with its aberrant state.
    #
    #   This work-around is the only case of a save template modification to handle a position special
    #   case. Note that the {CaTissue::SpecimenPosition} logic does not apply to a
    #   {CaTissue::ContainerPosition}, which can be updated directly.
    #
    #   The additional complexity of this work-around is necessitated by the caTissue policy of update
    #   by indirect server-side side-effects that are not reflected back to the client. The caRuby
    #   declarative API policy persists the save argument as given and reflects the changed database
    #   state. That policy requires this work-around.
    #
    # @quirk caTissue  Bug #63: A SpecimenCollectionGroup update requires that the referenced
    #   CollectionProtocolRegistration hold extraneous content, including the CPR collection
    #   protocol and PPI.
    #
    # @quirk caTissue Bug: CollectionProtocolRegistration must cascade through the
    #   CollectionProtocol, but the CP events cannot cascade to SpecimenRequirement without
    #   raising an Exception. The work-around is to clear the template CP events.
    #
    # @quirk caTissue Update SpecimenCollectionGroup requires a collection and received event parameter,
    #   even if the collection status is pending. Work-around is to add default parameters.
    #
    # @quirk caTissue Create Specimen with nil label does not auto-generate the label.
    #   Work-around is to set the label to a unique value.
    #
    # @quirk caTissue When caTissue updates a Specimen referencing a child Specimen with an identifier which
    #   is setting the collection status to +Collected+ and has a received or collection event parameters
    #   without an identifier, then caTissue creates the referenced event parameters as well as spurious
    #   auto-generated received and collection event parameters. This behavior differs from the top-level
    #   Specimen, where the event parameters in the argument are simply ignored. The work-around is to
    #   recursively strip the derived received and collection event parameters, then fetch, match and resave
    #   the stripped event parameters. This behavior is not entirely confirmed, because the various forms
    #   of caTissue event parameters corruption are hard to isolate and catalog. The best recourse is to
    #   assume that caTissue will ignore or corrupt any received and collection event parameters references
    #   and strip, fetch, match and resave these event parameters separately.
    #
    # @quirk caTissue When caTissue updates a pending SCG to status Complete then a collection and
    #   received event parameters is added to each referenced top-level specimen, even though the
    #   specimen status is not updated from Pending to Collected. Event parameters are not added to
    #   child specimens.
    #
    # @param obj [Resource] obj the object to save
    # @param [Resource] template the template to submit to caCORE
    # @raise DatabaseError if the object to save is an {Annotation::Proxy}, which is not supported
    def save_with_template(obj, template)
      # special cases to work around caTissue bugs
      if CaTissue::CollectionProtocolRegistration === obj  and template.collection_protocol then
        template.collection_protocol.collection_protocol_events.clear
      elsif CaTissue::Specimen === obj then
        # if template.identifier.nil? and template.label.nil? then
        #   logger.debug { "Work around caTissue label bug by setting the #{obj.qp} create template #{template.qp} label to a unique value." }
        #   template.label = Jinx::Uniquifier.qualifier
        # end
        if obj.position and obj.position.identifier then
          add_position_to_specimen_template(obj, template)
        end
        # Anticipate the caTissue disposed Specimen update side-effect by removing
        # the consent tier statuses.
        if obj.disposed? then
          unless obj.consent_tier_statuses.empty? then
            obj.consent_tier_statuses.clear
            template.consent_tier_statuses.clear
            logger.debug { "Anticipated a caTissue side-effect by clearing the disposed #{obj.qp} consent tier statuses prior to save." }
          end
        end
      # TODO - is there a test case for this? Isn't EID create delegated to
      # specimen create, which cascades to the EID?
      # elsif obj.identifier.nil? and CaTissue::ExternalIdentifier === obj then
      #   # application service save
      #   result = submit_save_template(obj, template)
      #   # if app service is not broken, then sync the result and return
      #   if obj.identifier then
      #     sync_saved(obj, result)
      #     return
      #   end
      #   logger.debug { "Work around caTissue ExternalIdentifier create bug by updating the phantom caTissue auto-generated empty #{obj.specimen} EID directly with SQL..." }
      #   # app service is broken; fetch the identifier and set directly via SQL
      #   tmpl = obj.class.new
      #   tmpl.setSpecimen(obj.specimen)
      #   eids = query(tmpl).select { |eid| eid.name.nil? }
      #   if eids.size > 1 then
      #     raise DatabaseError.new("#{spc} has more than external identifier without a name: #{eids}")
      #   end
      #   # Set the identifier.
      #   obj.identifier = eids.first.identifier
      #   # Call the SQL
      #   @executor.transact(UPD_EID_SQL, obj.name, obj.value, obj.specimen.identifier, obj.identifier)
      #   logger.debug { "caTissue #{obj} create work-around completed." }
      #   return
      elsif obj.identifier and CaTissue::SpecimenEventParameters === obj then
        # TODO - this case occurs in the simple_test migration; fix it there and remove this check.
        # TODO - KLUDGE!!!! FIX AT SOURCE AND REMOVE SEP KLUDGE AS WELL!!!!
        # Fix this with an auto-gen add_defaults?
        if template.user.nil? then template.user = query(template, :user).first end
        if template.specimen.nil? and template.specimen_collection_group.nil? then
           template.specimen = query(template, :specimen).first
           template.specimen_collection_group = query(template, :specimen_collection_group).first
        end
      elsif obj.identifier and CaTissue::SpecimenCollectionGroup === obj then
        # add the extraneous SCG template CPR protocol and PPI, if necessary 
        cpr = obj.collection_protocol_registration
        if cpr.nil? then raise Jinx::ValidationError.new("#{obj} cannot be updated since it is missing a CPR") end
        tcpr = template.collection_protocol_registration
        if tcpr.nil? then raise Jinx::ValidationError.new("#{obj} CPR #{cpr} was not copied to the update template #{tcpr}") end
        if tcpr.collection_protocol.nil? then
          pcl = lazy_loader.enable { cpr.collection_protocol }
          if pcl.nil? then raise Jinx::ValidationError.new("#{obj} cannot be updated since it is missing a referenced CPR #{cpr} protocol") end
          tpcl = pcl.copy(:identifier)
          logger.debug { "Work around caTissue bug by adding extraneous #{template} #{tcpr} protocol #{tpcl}..." }
          tmpl.collection_protocol = tpcl
        end
        if tcpr.protocol_participant_identifier.nil? then
          ppi = lazy_loader.enable { cpr.protocol_participant_identifier }
          if ppi.nil? then
            raise Jinx::ValidationError.new("#{obj} cannot be updated since it is missing a referenced CPR #{cpr} PPI required to work around a caTissue SCG update bug")
          end
          tppi = ppi.copy(:identifier)
          logger.debug { "Work around caTissue bug by adding extraneous #{template} #{tcpr} PPI #{tppi}..." }
          tmpl.protocol_participant_identifier = tppi
        end
        unless obj.received? then
          rep = obj.instance_eval { create_default_received_event_parameters }
          if rep.nil? then raise CaRuby::DatabaseError.new("Default received event parameters were not added to #{obj}.") end
          rep.copy.merge_attributes(:user => rep.user, :specimen_collection_group => template)
        end
        unless obj.collected? then
          cep = obj.instance_eval { create_default_collection_event_parameters }
          if cep.nil? then raise CaRuby::DatabaseError.new("Default collection event parameters were not added to #{obj}.") end
          cep.copy.merge_attributes(:user => cep.user, :specimen_collection_group => template)
        end
      elsif Annotation::Proxy === obj then
        raise CaRuby::DatabaseError.new("Annotation proxy direct database save is not supported: #{obj}")
      elsif Annotation === obj and obj.class.primary? then
        copy_annotation_proxy_owner_to_template(obj, template)
      end

      # Work around a caTissue bug by removing CollectibleEventParameters.
      ceps = strip_collectible_event_parameters(obj, template) if Collectible === obj
      
      # delegate to the standard save
      super

      # post-process the deferred CEPs
      if ceps and not ceps.empty? then
        # the owner => target CEP hash
        hash = LazyHash.new { Array.new }
        ceps.each { |cep| hash[cep.owner] << cep }
        hash.each do |owner, teps|
          logger.debug { "Refetch the #{owner} event parameters to work around a caTissue bug..." }
          fetched = fetch_association(owner, :specimen_event_parameters)
          teps.each do |tep|
            match = fetched.detect { |fep| tep.class === fep }
            if match then
              logger.debug { "Matched the #{owner} event parameter #{tep} to the fetched #{fep}." }
              tep.merge(fep)
            else
              logger.debug { "#{owner} event parameter #{tep} does not match a fetched event parameters object." }
            end
          end
        end
      end
    end
    
    # Removes the unsaved {CollectibleEventParameters} from the given template to work around the
    # caTissue bug described in {#save_with_template}.
    #
    # The CollectibleEventParameters are required if and only if one of the following is true:
    # * the operation is a SCG save and the collected status is not pending
    # * the operation is an update to a previously collected Specimen
    # In all other cases, the CollectibleEventParameters are removed.
    #
    # This method is applied recursively to Specimen children.
    #
    # @param [Collectible] the Specimen or SCG template
    # @return [<CollectibleEventParameters>] the removed event parameters
    def strip_collectible_event_parameters(obj, template)
      if obj.collected? then
        return if CaTissue::SpecimenCollectionGroup === obj
        if obj.identifier then
          if obj.changed?(:collection_status) then
            fseps = fetch_association(obj, :specimen_event_parameters)
            obj.collectible_event_parameters.each do |cep|
              fcep = fseps.detect { |fsep| cep.class === fsep }
              cep.merge(fcep) if fcep
            end
            template.collectible_event_parameters.each do |cep|
              fcep = fseps.detect { |fsep| cep.class === fsep }
              cep.merge(fcep) if fcep
            end
          end
          return
        end
      end
      ceps = template.specimen_event_parameters.select { |ep| CollectibleEventParameters === ep }
      unless ceps.empty? then
        ceps.each { |cep| template.specimen_event_parameters.delete(cep) }
        logger.debug { "Worked around caTissue bug by stripping the following collectible event parameters from the #{template} template: #{ceps.pp_s}." }
      end
      if CaTissue::Specimen === template then
        obj.children.each do |spc|
          tmpl = spc.match_in(template.children)
          ceps.concat(strip_collectible_event_parameters(spc, tmpl)) if tmpl
        end
      end
      ceps
    end
    
    #
    # @quirk caTissue When caTissue updates a pending Specimen to status Complete, an auto-generated
    #   collection and received event parameters is added to the Specimen even if the Specimen already
    #   has a collection and received event parameters. The redundant event parameters corrupts the
    #   database content and sporadically results in a GUI Severe Server Error with no trace-back.
    #   Work around this bug by deleting the extraneous CollectibleEventParameters.
    #   Hammer the database directly to back out this insidious caTissue-generated corruption.
    def submit_save_template(obj, template)
      result = super
      
      if CaTissue::Specimen === obj and obj.identifier and obj.collected? and obj.changed?(:collection_status) then
        fseps = query(obj.copy(:identifier), :specimen_event_parameters)
        obj.collectible_event_parameters.each do |cep|
          next if cep.identifier.nil?
          bogus = fseps.detect { |fsep| cep.class === fsep and cep.identifier != fsep.identifier } || next
          logger.debug { "Work around caTissue event parameters auto-corruption bug by deleting the bogus #{bogus}..." }
          table = case bogus.class.name.demodulize
          when 'CollectionEventParameters' then 'catissue_coll_event_param'
          when 'ReceivedEventParameters' then 'catissue_received_event_param'
          else raise CaRuby::DatabaseError.new("Collectible event parameter class not recognized: #{bogus.class}")
          end
          sql = "delete from #{table} where identifier = ?"
          executor.transact(sql, bogus.identifier)
          sql = "delete from catissue_specimen_event_param where identifier = ?"
          executor.transact(sql, bogus.identifier)
          logger.debug { "Worked around caTissue event parameters auto-corruption bug by deleting the bogus #{bogus}." }
        end
      end
      
      result
    end
    
    # The annotation proxy is not copied because the attribute redirects to the hook rather
    # than the proxy. Set the template copy source proxy to the target object proxy using
    # the low-level Java property methods instead.
    #
    # @param [Annotation] obj the copy source
    # @param [Annotation] template the copy target
    def copy_annotation_proxy_owner_to_template(obj, template)
      prop = obj.class.proxy_property
      # Ignore the proxy attribute if it is defined by caRuby rather than caTissue.
      return unless prop and prop.java_property?
      rdr, wtr = prop.property_accessors
      pxy = obj.send(rdr)
      logger.debug { "Setting #{obj.qp} template #{template.qp} proxy owner to #{pxy}..." }
      template.send(wtr, pxy)
    end

    # Augment +CaRuby::Database::Writer.create_object+ to work around caTissue bugs and pass through
    # an {Annotation::Proxy} to the referenced annotations.
    #
    # @quirk caTissue Bug #124: SCG SpecimenEventParameters save fails validation.
    #   Work-around is to create the SEP by updating the SCG.
    #
    # @quirk caTissue If the save argument domain object is a CaTissue::Specimen with the +is_available+
    # flag set to false, then work around the bug described in {#create_unavailable_specimen}.
    #
    # @quirk caTissue Bug #161: Specimen API disposal is not reflected in the saved result activity status.
    #   DisposalEventParameters create sets the owner Specimen activity_status to +Closed+ as a side-effect.
    #   Reflect this side-effect in the submitted DisposalEventParameters owner Specimen object.
    #
    # @quirk caTissue 1.2 An undocumented caTissue "feature" is that Specimen API disposal clears the
    #   Specimen consent tier statuses as a side-effect. Reflect this side-effect in the submitted
    #   DisposalEventParameters owner Specimen object.
    #
    # @quirk caTissue 1.2 Creating a specimen aliquot without a label or barcode resuts in a server 
    #   uniqueness constraint failure SQL error. Work-around is to generate the aliquot and barcode
    #   on the fly.
    #
    # @quirk caTissue caTissue API create with an Address argument completes without an exception but
    #   silently ignores the argument and does not create the record. The create call has a result
    #   that is a copy of the argument, including the missing identifier.
    #   Unlike the {Database} {#create} method, this private {#create_object} method must allow an Address
    #   object in order to support the user address update caTissue bug work-around. However, the address
    #   update bug work-around encounters the Address create missing id caTissue bug. The
    #   work-around for this caTissue bug work-around bug is to bypass the caTissue API, hit the database
    #   directly with SQL, find the matching database record, and set the identifier to the matching record
    #   identifier. The match is complicated by the possibility that a different client might create an
    #   address after the SQL transaction but before the max id query. The work-around for this potential
    #   caTissue bug work-around bug work-around bug is to fetch addresses until one matches, then set the
    #   created address identifier to that fetched record identifier.
    #
    # @param [Resource] obj the dependent domain object to save
    def create_object(obj)
      if CaTissue::Address === obj then
        return create_address(obj)
      elsif CollectibleEventParameters === obj and obj.specimen_collection_group then
        return save_collectible_scg_event_parameters(obj)
      elsif CaTissue::Specimen === obj then
        obj.add_defaults
        # Work around aliquot bug
        if obj.parent and obj.characteristics == obj.parent.characteristics then
          if obj.label.nil? then
            obj.label = obj.barcode = Jinx::Uniquifier.qualifier
            logger.debug { "Worked around caTissue 1.2 bug by creating #{obj} aliquot label and barcode." }
          end
          obj.barcode = obj.label if obj.barcode.nil?
        end
        # Special case for an unavailable specimen.
        # The obj.is_available == false test is required as opposed to obj.is_available?,
        # since a nil is_available flag does not imply an unavailable specimen.
        if obj.is_available == false or obj.available_quantity.zero? or obj.disposed? then
          return create_unavailable_specimen(obj)
        end
      end
      
      # standard create
      super

      # replicate caTissue create side-effects in the submitted object
      if CaTissue::DisposalEventParameters === obj then
        obj.specimen.activity_status = 'Closed'
        logger.debug { "Set the created DisposalEventParameters #{obj.qp} owner #{obj.specimen.qp} activity status to Closed." }
        unless obj.specimen.consent_tier_statuses.empty? then
          obj.specimen.consent_tier_statuses.clear
          logger.debug { "Cleared the created DisposalEventParameters #{obj.qp} owner #{obj.specimen.qp} consent tier statuses." }
        end
      end
      
      obj
    end
    
    # The Address attribute => column map for those attributes whose column differs from the attribute name.
    ADDRESS_ATTR_COL_HASH = { :zip_code => :zipcode }
    
    # @param [CaTissue::Address] address the address to create
    # @return [CaTissue::Address] the created address
    # @raise [CaRuby::DatabaseError] if the address could not be created
    # @see #create_object
    def create_address(address)
      vh = address.value_hash
      cols = vh.keys.map { |pa| ADDRESS_ATTR_COL_HASH[pa] or pa }
      sql = "insert into catissue_address ( #{cols.join(', ')} )\nvalues ( #{Array.new(vh.size).fill('?').join(', ')} )"
      logger.debug { "Bypass the broken caTissue API address create and hit the database directly." }
      next_addr_id = executor.query(MAX_ADDR_ID_SQL).first.first
      executor.transact(sql, *vh.values)
      while fetched = CaTissue::Address.new(:identifier => next_addr_id).find do
        if vh.all? { |pa, v| fetched.send(pa) == v } then
          address.identifier = fetched.identifier
          address.take_snapshot
          logger.debug { "Created #{address.qp}." }
          return address
        end
        next_addr_id += 1
      end
      raise CaRuby::DatabaseError.new("No address found which matches the created #{address}")
    end
    
    # Overrides +CaRuby::Database.create_from_template+ as follows:
    # * Surrogate {Annotation::Proxy} is "created" by setting the identifier to its hook owner.
    #   The create operation then creates referenced uncreated dependents.
    #
    # @param (CaRuby::Database#create_from_template)
    def create_from_template(obj)
      if Annotation::Proxy === obj then
        hook = obj.hook
        if hook.identifier.nil? then
          raise CaRuby::DatabaseError.new("Annotation proxy #{obj.qp} hook owner #{hook.qp} does not have an identifier")
        end
        obj.identifier = hook.identifier
        obj.take_snapshot
        logger.debug { "Marked annotation proxy #{obj} as created by setting the identifier to that of the hook owner #{hook}." }
        logger.debug { "Creating annotation proxy #{obj} dependent primary annotations..." }
        save_changed_dependents(obj)
        persistify(obj)
        obj
      else
        super
      end
    end
    
    # Creates the given specimen by working around the following bug:
    #
    # @quirk caTissue Bug #160: Missing Is Available? validation.
    #   Cannot create a Specimen with any of the following conditions:
    #   * zero available_quantity
    #   * is_available flag set to false
    #   * activity_status is +Closed+
    #   
    #   The work-around is to set the flags to true and +Active+, resp., set the quantities
    #   to a non-zero value, create the Specimen and then update the created Specimen with
    #   the original values.
    #   
    #   If the specimen has a disposal event, then this work-around interacts with the
    #   {#save_changed_dependents} work-around as follows:
    #   * Delete that event from the Specimen.
    #   * Create the Specimen as described above.
    #   * Update the Specimen as described above, but do not set the activity_status to +Closed+.
    #   * Create the pending disposal event.
    #
    # @param [CaTissue::Specimen] specimen the specimen to create
    def create_unavailable_specimen(specimen)
      logger.debug { "Resetting #{specimen} quantities and available flag temporarily to work around caTissue Bug #160..." }
      specimen.is_available = true
      # Capture the intended initial quantity and status.
      oiqty = specimen.initial_quantity
      ostatus = specimen.activity_status
      # Reset the quantities and status to values which caTissue will accept.
      specimen.initial_quantity = 1.0
      specimen.available_quantity = 1.0
      specimen.activity_status = 'Active'
      # Cannot reset a disposed Specimen quantity, so postpone disposal until
      # quantities are reset. 
      dsp = specimen.specimen_events.detect { |sep| CaTissue::DisposalEventParameters === sep }
      if dsp then specimen.specimen_events.delete(dsp) end

      # Delegate to the standard create.
      self.class.superclass.instance_method(:create_object).bind(self).call(specimen)

      logger.debug { "Complete the caTissue Bug #160 work-around by reupdating the created #{specimen} with the initial quantity set back to the original value..." }
      # Restore the available flag and initial quantity.
      specimen.is_available = false
      specimen.initial_quantity = oiqty
      # The available quantity is always zero, since the available flag is set to false.
      specimen.available_quantity = 0.0
      # Leave status Active if there is a disposal event, since quantities cannot be reset
      # on a closed Specimen and creating the disposal event below will close the Specimen.
      specimen.activity_status = ostatus unless dsp
      # Update directly without a cyclic operation check, since update(specimen) of a
      # derived specimen delegates to the parent, which in turn might be the outer
      # save context.
      update_from_template(specimen)
      
      # Finally, create the disposal event if one is pending.
      if dsp then
        specimen.specimen_events << dsp
        create(dsp)
      end
      
      logger.debug { "#{specimen} caTissue Bug #160 work-around completed." }
      specimen
    end
    
    # Augments +CaRuby::Database::Persistifier.detoxify+ to work around the
    # caTissue bugs described in {CaTissue::Specimen.remove_phantom_external_identifier}
    # and {CaTissue::Participant.remove_phantom_medical_identifier}.
    #
    # @param [Resource, <Resource>] the toxic domain object(s)
    def detoxify(toxic)
      if toxic.collection? then
        case toxic.first
        when CaTissue::ExternalIdentifier then
          CaTissue::Specimen.remove_phantom_external_identifier(toxic)
        when CaTissue::ParticipantMedicalIdentifier then
          CaTissue::Participant.remove_phantom_medical_identifier(toxic)    
        end
      end
      super
    end
    
    # @see #detoxify
    def clear_toxic_attributes(toxic)
      super
      case toxic
      when CaTissue::Specimen then
        CaTissue::Specimen.remove_phantom_external_identifier(toxic.external_identifiers)
      when CaTissue::Participant then
        CaTissue::Participant.remove_phantom_medical_identifier(toxic.participant_medical_identifiers)    
      end
    end

    # Overrides +CaRuby::Database::Reader.fetch_object} to circumvent {Annotation+ fetch, since an annotation
    # does not have a key.
    def fetch_object(obj)
      super or fetch_alternative(obj)
    end

    def fetch_alternative(obj)
      case obj
        when CaTissue::Specimen then fetch_specimen_alternative(obj)
        when CaTissue::Participant then fetch_participant_alternative(obj)
      end
    end

    # @quirk JRuby Fetching a specimen with consent_tier_statuses can replace the status with
    #   a different, empty status. The status swizzle occurs even though the attribute fetched
    #   is not the consent_tier_statuses and the statuses are not touched. The work-around,
    #   believe it or not, is to reference the consent_tier_statuses after the fetch.
    #   This problem occurs in the caSmall update_spec test.
    def fetch_association(obj, attribute)
      result = super
      obj.consent_tier_statuses if CaTissue::Specimen === obj
      result
    end
    
    # @quirk JRuby fetching a CPR CP swizzles the CPR participant. This only occurs when the CP exists in
    #   the database. The work-around is to reset the swizzled participant. However, merely capturing the
    #   participant before the CP find is sufficient to prevent this bug. JRuby does not corrupt the CPR
    #   participant if it is referenced by a local variable. The CPR is too complicated to reformulate as
    #   this bug as an isolated non-caTissue test case.
    def finder_parameter(obj, attribute)
      if CaTissue::CollectionProtocolRegistration === obj and attribute == :collection_protocol then
        # Simply assigning the pnt variable prevents the bug from occurring.
        pnt = obj.participant
      end
      value = super
      if value and pnt and pnt != obj.participant then
        swzld = obj.participant
        obj.participant = pnt
        logger.debug { "Worked around #{obj} corruption by restoring the swizzled participant from #{swzld} to the original #{pnt}." }
      end
      value
    end
    
    # Augments the +CaRuby::Writer+ exclusion filter to exclude annotations from the create template.
    # Annotations are created following the owner create.
    #
    # @param obj (see #create_object)
    # @param [CaRuby::Property] prop the candidate attribute metadata
    # @return [Boolean] whether the attribute should not be included in the create template
    def exclude_pending_create_attribute?(obj, prop)
      prop.type < Annotation or super
    end

    # @quirk caTissue Bug #147: SpecimenRequirement query ignores CPE.
    #   Work around this bug by an inverted query on the referenced CPE.
    #
    # @quirk caTissue Accessing an annotation hook DE proxy attribute uses a separate mechanism.
    #   Redirect the query to the annotation integration service in that case.
    #
    # @quirk caTissue Bug #169: ContainerPosition occupied container query returns parent
    #   container instead. Substitute a hard-coded HQL search for this case.
    #
    # @see CaRuby::Database#query_object
    def query_object(obj, attribute=nil)
      if hook_proxy_attribute?(obj, attribute) then
        query_hook_proxies(obj, attribute)
      elsif CaTissue::SpecimenRequirement === obj and not obj.identifier and obj.collection_protocol_event then
        query_requirement_using_cpe_inversion(obj, attribute)
      elsif CaTissue::ContainerPosition === obj and obj.identifier and attribute == :occupied_container then
        query_container_position_occupied_container(obj, attribute)
      else
        super
      end
    end
    
    def query_container_position_occupied_container(obj, attribute)
      logger.debug { "Work around caTissue bug by querying #{obj} #{attribute} using HQL..." }
      src = obj.class.java_class.name
      query("select pos.occupiedContainer from #{src} pos where pos.id = #{obj.identifier}")
    end
    
    # @param (see #query_object)
    # @return [Boolean] whether the given attribute is a reference from an {Annotatable} to a #{Annotation::Proxy}
    def hook_proxy_attribute?(obj, attribute)
      return false if attribute.nil?
      prop = obj.class.property(attribute)
      prop.declarer < Annotatable and prop.type < Annotation::Proxy
    end
    
    # Queries on the given object attribute using the {Annotation::IntegrationService}.
    #
    # @param [Annotatable] hook the annotated domain object
    # @param [Symbol] attribute the proxy attribute
    # @result (see #query_object)
    def query_hook_proxies(hook, attribute)
      unless hook.identifier then
        logger.debug { "Querying annotation hook #{hook.qp} proxy reference #{attribute} by collecting the matching #{hook.class.qp} proxy references..." }
        return query(hook).map { |ref| query_hook_proxies(ref, attribute) }.flatten
      end
      # the hook proxies
      proxies = hook.send(attribute)
      # catenate the query results for each proxy
      proxies.each { |pxy| find_hook_proxy(pxy, hook) }
      proxies
    end    
    
    # Queries on the given proxy using the {Annotation::IntegrationService}.
    #
    # @param [Annotation::Proxy] proxy the proxy object
    # @param hook (see #query_hook_proxies)
    # @param [Symbol] attribute the proxy attribute
    # @result (see #query_object)
    def find_hook_proxy(proxy, hook)
      # update the proxy identifier if necessary
      proxy.identifier ||= hook.identifier
      # delegate to the integration service to find the  referenced hook annotation proxies
      logger.debug { "Delegating #{hook.qp} proxy #{proxy} query to the integration service..." }
      annotator.integrator.find(proxy)
    end
    
    # @quirk caCORE Override +CaRuby::Database::Reader.invertible_query?+ to enable the Bug #147 work
    #   around in {#query_object}. Invertible queries are performed to work around Bug #79. However, this
    #   work-around induces Bug #147, so we disable the Bug #79 work-around here for the special case of
    #   a CPE in order to enable the Bug #147 work-around. And so it goes....
    #
    # @see CaRuby::Database#invertible_query?
    def invertible_query?(obj, attribute)
      super and not (hook_proxy_attribute?(obj, attribute) or
        (CaTissue::CollectionProtocolEvent === obj and attribute == :specimen_requirements))
    end

    def fetch_participant_alternative(pnt)
      fetch_participant_using_ppi(pnt) or fetch_participant_using_mrn(pnt)
    end

    def fetch_participant_using_ppi(pnt)
      cpr = pnt.registrations.first
      return if cpr.nil?
      logger.debug { "Using alternative Participant fetch strategy to find Participant by protocol participant identifier..." }
      return unless exists?(cpr)
      candidates = query(cpr.copy, :participant)
      candidates.first if candidates.size == 1
    end

    def fetch_participant_using_mrn(pnt)
      pmi = pnt.medical_identifiers.first
      return if pmi.nil?
      logger.debug { "Using alternative Participant fetch strategy to find Participant by medical record number..." }
      # If the PMI has an identifier (unlikely) then find the PMI participant.
      if pmi.identifier then return query(pmi.copy, :participant).first end
      # Add the default site. If no default site, then bail.
      if pmi.site.nil? then
        pmi.add_defaults
        return unless pmi.site
      end
      return unless exists?(pmi.site)
      # Find the PMI based on the site and MRN.
      return query(pmi.copy(:site, :medical_record_number), :participant).first
    end

    # @param [CaTissue::Specimen] spc the specimen to fetch
    # @return [CaTissue::Specimen, nil] the fetched specimen which matches the spc on at least one external identifier,
    #   or nil if no match
    def fetch_specimen_alternative(spc)
      eid = spc.external_identifiers.detect { |eid| eid.identifier } || spc.external_identifiers.first || return
      logger.debug { "Using alternative Specimen fetch strategy to find #{spc} by external identifier #{eid}..." }
      candidates = query(eid.copy, :specimen)
      candidates.first if candidates.size == 1
    end

    # @param [CaTissue::SpecimenCollectionGroup] scg the SCG to query
    # @return [<CaTissue::Specimen>] the fetched SCG specimens
    def query_scg_specimens_using_specimen_reference(scg)
      spc = CaTissue::Specimen.new(:specimen_collection_group => scg.copy)
      logger.debug { "Using alternative SCG specimens query strategy to find Specimens by Specimen SCG reference #{scg.qp}..." }
      query(spc)
    end

    # @param [CaTissue::SpecimenRequirement] scg the requirement to query
    # @return [<Resource>] the fetched requirement or requirement attribute reference
    def query_requirement_using_cpe_inversion(rqmt, attribute=nil)
      cpe = rqmt.collection_protocol_event
      logger.debug { "Using alternative SpecimenRequirement query strategy to find SpecimenRequirements by inverted CPE reference #{cpe}..." }
      attribute ? query(cpe, :specimen_requirements, attribute) : query(cpe, :specimen_requirements)
    end
  end
end
