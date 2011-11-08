require 'singleton'
require 'caruby/util/uniquifier'
require 'caruby/util/validation'
require 'caruby/util/topological_sync_enumerator'
require 'caruby/database'
require 'catissue/database/annotation/annotator'
require 'catissue/util/collectible_event_parameters'

module CaTissue
  # Database mediates access to the caTissue application server.
  # Superclass +CaRuby::Database+ functionality base class methods are overridden as necessary
  # to enable caTissue-specific work-arounds and alternate search strategies.
  # A CaTissue::Database mediates access to the caTissue database.
  # The CaRuby::Database functionality is preserved and not expanded, but this CaTissue::Database overrides
  # several base class private methods to enable alternate CaTissue-specific search strategies and work
  # around caTissue and caCORE bugs.
  class Database < CaRuby::Database
    include Singleton
    
    # return [CaRuby::SQLExecutor] a utility SQL executor
    attr_reader :executor

    # Creates a new Database with the +catissuecore+ service and {#access_properties}.
    def initialize
      super(SVC_NAME) { access_properties }
      @executor = CaRuby::SQLExecutor.new(access_properties)
    end
    
    # @return (see CaRuby::Domain.properties)
    def access_properties
      # The access properties are a subset of the application properties.
      CaTissue.properties
    end

    # @return [Annotator] the annotator utility
    def annotator
      @annotator ||= Annotator.new(self)
    end

    # If the given domain object is an {Annotation}, then this method returns the {AnnotationService}
    # for the object {AnnotationModule}, otherwise this method returns the standard {CaTissue::Database}
    # service.
    #
    # @param (see CaRuby::Database#persistence_service)
    # @return (see CaRuby::Database#persistence_service)
    def persistence_service(klass)
      klass < Annotation ? klass.annotation_module.persistence_service : super
    end
    
    # Augments {CaRuby::Database#ensure_exists} to ensure that an {Annotation::Proxy} reference identifier
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

    # Overrides #{CaRuby::Database::Writer#recursive_save?} to support the update work-around
    # described in {#update_object}. A recursive SCG update is allowed if the nested
    # transaction sequence is:
    # * Update SCG
    # * Update SCG event parameters as part of Update SCG
    # * Update SCG as part of the Bug #135 work-around
    #
    # @param (see CaRuby::Database::Writer#recursive_save?)
    # @return (see CaRuby::Database::Writer#recursive_save?)
    def recursive_save?(obj, operation)
      super and not scg_event_update_workaround?(obj, operation)
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
        ref.set_attribute(attribute, resolved)
      end
    end

    # @quirk caTissue Bug #135: Update SCG SpecimenEventParameters raises AuditException.
    #   Work around is to update the SCG instead.
    # @quirk caTissue CPR consent tier response update results in Access denied error.
    #   Work-around is to update the response using a direct SQL call.
    #
    # @param (see CaRuby::Database#update_object)
    # @return (see CaRuby::Database#update_object)
    def update_object(obj)
      if collectible_event_parameters?(obj) then
        save_collectible_event_parameters(obj)
      elsif CaTissue::ConsentTierResponse === obj then
        update_consent_tier_response(obj)
      elsif Annotation === obj then
         raise CaRuby::DatabaseError.new("Annotation update is not supported on #{obj}")
      else
        case obj
          when CaTissue::Specimen then
            # Specimen activity status is not always set to default; don't know why.
            # TODO - isolate and fix at source
            obj.activity_status ||= 'Active'
          when CaTissue::StorageContainer then
            logger.debug { "Fetching #{obj} storage type prior to update..." }
            if obj.storage_type.nil? then lazy_loader.enable { obj.storage_type } end
        end
        super
      end
    end
    
    # Updates the given dependent.
    #
    # @quirk caTissue 1.2 user address update results in authorization error. Work-around is to
    #   create a new address record.
    #
    # @param (see CaRuby::Writer#update_changed_dependent)
    def update_changed_dependent(owner, attribute, dependent, autogenerated)
      if CaTissue::User === owner and attribute == :address then
        update_user_address(owner, dependent)
      else
        super
      end
    end
    
    # Updates the given user address.
    #
    # @param [CaTissue::User] the user
    # @param [CaTissue::Address] the address to update
    def update_user_address(user, address)
      logger.debug { "Work around caTissue prohibition of #{user} address #{address} update by creating a new address record..." }
      address.identifier = nil
      create(address)
      perform(:update, user) { update_object(user) }
      fetched = query(user, :address).first
      address.identifier = fetched.identifier
      logger.debug { "#{user} address identifier reset to #{address.identifier}." }
    end
    
    # Returns whether operation is the second SCG Update described in {#recursive_save?}.
    def scg_event_update_workaround?(obj, operation)
      # Is this an SCG update?
      return false unless CaTissue::SpecimenCollectionGroup === obj and operation == :update
      last = @operations.last
      # Is the nesting operation on an SEP?
      return false unless last and collectible_event_parameters?(last.subject)
      ev = last.subject
      # Is the SEP SCG the same as the target SCG?
      return false unless ev.specimen_collection_group == obj
      penultimate = @operations[-2]
      # Is the operation which nests the SEP operation a SCG update on the same SCG?
      penultimate and penultimate.subject == obj
    end
      
    # Augments {CaRuby::Database#save_with_template} to work around the following caTissue anomalies:
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
    #   done automatically by {CaRuby::Database} as part of the save proxy mechanism. The Specimen update
    #   template must include a reference to the former position but not the changed position.
    #
    #   However, the Specimen {CaRuby::Writer#update} argument will include the changed position, not the
    #   former position. The template built {CaRuby::Writer#update} for submission to the caTissue app
    #   does not include a position reference, since the position has a save proxy which handles position
    #   change as part of the {CaRuby::Writer} update dependent propagation.
    #
    #   Thus, updating a Specimen which includes a position change is performed as follows:
    #   * reconstitute the former position from the Position snapshot taken as part of the
    #      {CaRuby::Persistable} change tracker.
    #   * add the former position to the template (which will now differ from the {CaRuby::Writer#update}
    #     argument).
    #   * submit the adjusted Specimen template to the caTissue app updateObject.
    #   * {CaRuby::Writer#update} will propagate the Specimen update to the changed position dependent,
    #     which in turn saves via the {CaTissue::TransferEventParameters} proxy.
    #   * The proxy save will in turn refetch the proxied Specimen position to obtain the identifier
    #     and merge this into the Specimen position.
    #   * The Specimen update template is used solely to satisfy the often arcane caTissue interaction
    #     requirements like this work-around, and is thrown away along with its aberrant state.
    #
    #   This work-around is the only case of a save template modification to handle a caTissue special
    #   case. Note that the {CaTissue::SpecimenPosition} logic does not apply to a
    #   {CaTissue::ContainerPosition}, which can be updated directly.
    #
    #   The additional complexity of this work-around is necessitated by the caTissue policy of update
    #   by indirect server-side side-effects that are not reflected back to the client. The caRuby
    #   policy of a declarative API that persists the save argument as given and reflects the
    #   changed database state requires this work-around.
    #
    # @param obj (see #store)
    # @param [Resource] template the obj template to submit to caCORE
    def save_with_template(obj, template)
      if CaTissue::Specimen === obj and obj.position and obj.position.identifier then
        add_position_to_specimen_template(obj, template)
      end
      super
    end
    
    # Adds the specimen position to its save template.
    #
    # @param [CaTissue::Specimen] specimen the existing specimen with an existing position
    # @param template (see #save_with_template) 
    # @see {#save_with_template}
    def add_position_to_specimen_template(specimen, template)
      pos = specimen.position
      # the non-domain position attributes
      attrs = pos.class.nondomain_attributes
      # the template position reflects the old values, if available
      ss = pos.snapshot
      # the attribute => value hash
      vh = ss ? attrs.to_compact_hash { |attr| ss[attr] } : pos.value_hash(attrs)
      vh[:specimen] = template
      vh[:storage_container] = pos.storage_container.copy
      # the template position reflects the old values
      template.position = pos.class.new(vh)
      logger.debug { "Work around #{specimen} update anomaly by copying position #{template.position.qp} to update template #{template.qp} as #{template.position.qp} with values #{vh.qp}..." }
    end
    
    # @return [Boolean] whether obj is a CollectibleEventParameters with a SCG owner
    def collectible_event_parameters?(obj)
      CollectibleEventParameters === obj and obj.specimen_collection_group
    end

    # @param [CollectibleEventParameters] ep the SCG event parameters to save
    # @return (see CaRuby::Database#update_object)
    # @see #create_object
    # @see #update_object
    def save_collectible_event_parameters(ep)
      scg = ep.specimen_collection_group
      logger.debug { "Work around #{ep.qp} caTissue SCG SpecimenEventParameters update bug by updating the owner #{scg.qp} instead..." }
      ensure_exists(scg)
      # update the CollectibleEventParameters by updating the SCG
      update(scg)
      raise CaRuby::DatabaseError.new("Update SCG did not cascade to dependent #{ep}") unless ep.identifier
      ep
    end
    
    
    # @param [CaTissue::Consent_TierResponse] ctr the response to update
    # @see #update_object
    def update_consent_tier_response(ctr)
        # Call the SQL
        logger.debug { "Work around caTissue #{ctr} update bug by submitting direct SQL call..." }
        @executor.execute { |dbh| dbh.do(UPD_CTR_SQL, ctr.response, ctr.identifier) }
        logger.debug { "caTissue #{ctr} update work-around completed." }
    end

    # Overrides {CaRuby::Database::Writer#save_changed_dependents} to handle the following anomalies:
    # * create Specimen disposal event last, as described in {#save_changed_specimen_dependents}
    #
    # @param (see CaRuby::Writer#save_dependents)
    def save_changed_dependents(obj)
      case obj
        when Specimen then save_changed_specimen_dependents(obj) { super }
        else super
      end   
    end
    
    # Overrides {CaRuby::Database::Writer#save_changed_dependents} on a Specimen to correct the
    # following problem:
    #
    # @quirk caTissue DisposalEventParameters must be created after all other Specimen SEPs.
    #
    # The process for migrating a discarded Specimen is as follows:
    # * Create the Specimen with status Active.
    # * Create the non-disposal events.
    # * Create the DisposalEventParameters.
    #
    # {#save_changed_dependents} delegates to this method to handle the latter two steps.
    #
    # A DisposalEventParameters cannot be created for a closed Specimen. Conversely, caTissue closes
    # the Specimen as a side-effect of creating a DisposalEventParameters. Therefore, even if the
    # client submits a closed Specimen for create, this CaTissue::Database must first create the
    # Specimen with status Active, then submit the DisposalEventParameters.
    #
    # This is a work-around on top of the {#create_unavailable_specimen} work-around. See that method 
    # for the subtle interaction required between these two work-arounds.
    #
    # @param [CaTissue::Specimen] the specimen whose dependents are to be saved
    # @yield [dependent] calls the base {CaRuby::Writer#save_changed_dependents} 
    # @yieldparam [Resource] specimen the specimen to save
    def save_changed_specimen_dependents(specimen)
      dsp = specimen.specimen_events.detect { |ep| CaTissue::DisposalEventParameters === ep }
      if dsp then
        logger.debug { "Work around caTissue #{specimen.qp} event parameters save order dependency by deferring #{dsp.qp} save..." }
        specimen.specimen_events.delete(dsp)
      end
      
      begin
        yield specimen
      ensure
        specimen.specimen_events << dsp if dsp
      end
      
      # save the deferred disposal if any
      if dsp then
        logger.debug { "Creating deferred #{specimen.qp} dependent #{dsp.qp}..." }
        save_dependent(dsp)
      end
    end
    
    # Overrides {CaRuby::Database#build_save_template} to return obj itself if
    # obj is an {Annotation}, since annotations do not employ a separate template.
    #
    # @param (see CaRuby::Database#build_save_template)
    # @return (see CaRuby::Database#build_save_template)
    def build_save_template(obj, builder)
      Annotation === obj ? prepare_annotation_for_save(obj) : super
    end
    
    # Ensures that a primary annotation hook exists.
    #
    # @param [Annotation] annotation the object to create
    # @return [Annotation] the annotation object
    # @raise [DatabaseError] if the annotation does not reference a hook entity
    def prepare_annotation_for_save(annotation)
      hook = annotation.hook
      if hook.nil? then
        raise CaRuby::DatabaseError.new("Cannot save annotation #{annotation} since it does not reference a hook entity")
      end
      if hook.identifier.nil? then
        logger.debug { "Ensuring that the annotation #{annotation.qp} hook entity #{hook.qp} exists in the database..." }
        ensure_exists(hook)
      end
      annotation
    end

    # Overrides {CaRuby::Database::Writer#save_with_template} to work around caTissue bugs.
    # @quirk caTissue  Bug #63: a SpecimenCollectionGroup update requires the referenced CollectionProtocolRegistration
    #   with an identifier to hold extraneous CollectionProtocolRegistration content, including the CPR
    #   collection protocol and PPI.
    # @quirk caTissue Bug: CollectionProtocolRegistration must cascade throughCP, but the CP events
    #   cannot cascade to SpecimenRequirement without raising an Exception. Work-around is to clear the template CP events.
    # @quirk caTissue Create Specimen with nil label does not auto-generate the label.
    #   Work-around is to set the label to a unique value.
    #
    # @raise DatabaseError if the object to save is an {Annotation::Proxy}, which is not supported
    def save_with_template(obj, template)
      # special cases to work around caTissue bugs
      if CaTissue::CollectionProtocolRegistration === obj  and template.collection_protocol then
        template.collection_protocol.collection_protocol_events.clear
      elsif CaTissue::Specimen === obj then
        if template.label.nil? then
          logger.debug { "Work around caTissue label bug by setting the #{obj.qp} update template #{template.qp} label to a unique value." }
          template.label = Uniquifier.qualifier
        end
      elsif obj.identifier.nil? and CaTissue::ExternalIdentifier === obj then
        # application service save
        result = submit_save_template(obj, template)
        # if app service is not broken, then sync the result and return
        if obj.identifier then
          sync_saved(obj, result)
          return
        end
        logger.debug { "Work around caTissue ExternalIdentifier create bug by updating the bogus caTissue auto-generated empty #{obj.specimen} EID directly with SQL..." }
        # app service is broken; fetch the identifier and set directly via SQL
        tmpl = obj.class.new
        tmpl.setSpecimen(obj.specimen)
        eids = query(tmpl).select { |eid| eid.name.nil? }
        if eids.size > 1 then
          raise DatabaseError.new("#{spc} has more than external identifier without a name: #{eids}")
        end
        # Set the identifier.
        obj.identifier = eids.first.identifier
        # Call the SQL
        @executor.execute { |dbh| dbh.do(UPD_EID_SQL, obj.name, obj.value, obj.specimen.identifier, obj.identifier) }
        logger.debug { "caTissue #{obj} create work-around completed." }
        return
      elsif obj.identifier and CaTissue::SpecimenEventParameters === obj then
        # TODO - this case occurs in the simple_test migration; fix it there and remove this check
        # TODO - KLUDGE!!!! FIX AT SOURCE AND REMOVE SEP KLUDGE AS WELL!!!!
        # fix this with an auto-gen add_defaults
        if template.user.nil? then template.user = query(template, :user).first end
        if template.specimen.nil? and template.specimen_collection_group.nil? then
           template.specimen = query(template, :specimen).first
           template.specimen_collection_group = query(template, :specimen_collection_group).first
        end
      elsif obj.identifier and CaTissue::SpecimenCollectionGroup === obj then
        # add the extraneous SCG template CPR protocol and PPI, if necessary 
        cpr = obj.collection_protocol_registration
        if cpr.nil? then raise ValidationError.new("#{obj} cannot be updated since it is missing a CPR") end
        tcpr = template.collection_protocol_registration
        if tcpr.nil? then raise ValidationError.new("#{obj} CPR #{cpr} was not copied to the update template #{tcpr}") end
        if tcpr.collection_protocol.nil? then
          pcl = lazy_loader.enable { cpr.collection_protocol }
          if pcl.nil? then raise ValidationError.new("#{obj} cannot be updated since it is missing a referenced CPR #{cpr} protocol") end
          tpcl = pcl.copy(:identifier)
          logger.debug { "Work around caTissue bug by adding extraneous #{template} #{tcpr} protocol #{tpcl}..." }
          tmpl.collection_protocol = tpcl
        end
        if tcpr.protocol_participant_identifier.nil? then
          ppi = lazy_loader.enable { cpr.protocol_participant_identifier }
          if ppi.nil? then raise ValidationError.new("#{obj} cannot be updated since it is missing a referenced CPR #{cpr} PPI") end
          tppi = ppi.copy(:identifier)
          logger.debug { "Work around caTissue bug by adding extraneous #{template} #{tcpr} PPI #{tppi}..." }
          tmpl.protocol_participant_identifier = tppi
        end
        #
        # TODO - why aren't obj SEPs below added with add_defaults_autogenerated in writer.rb?
        # 
        unless template.received? then
          if obj.received? then raise DatabaseError.new("#{obj} is received, but the generated template #{template} is not.") end
          rep = obj.instance_eval { create_default_received_event_parameters }
          if rep.nil? then raise CaRuby::DatabaseError.new("Default received event parameters were not added to #{obj}.") end
          rep.copy.merge_attributes(:user => rep.user, :specimen_collection_group => template)
        end
        unless template.collected? then
          cep = obj.instance_eval { create_default_collection_event_parameters }
          if cep.nil? then raise CaRuby::DatabaseError.new("Default collection event parameters were not added to #{obj}.") end
          cep.copy.merge_attributes(:user => cep.user, :specimen_collection_group => template)
        end
      elsif Annotation::Proxy === obj then
        raise CaRuby::DatabaseError.new("Annotation proxy direct database save is not supported: #{obj}")
      elsif Annotation === obj and obj.class.primary? then
        copy_annotation_proxy_owner_to_template(obj, template)
      end

      # delegate to standard save
      super
    end
    
    # The annotation proxy is not copied because the attribute redirects to the hook rather
    # than the proxy. Set the template copy source proxy to the target object proxy using
    # the low-level Java property methods instead.
    #
    # @param [Annotation] obj the copy source
    # @param [Annotation] template the copy target
    def copy_annotation_proxy_owner_to_template(obj, template)
      attr_md = obj.class.proxy_attribute_metadata
      # Ignore the proxy attribute if it is defined by caRuby rather than caTissue.
      return unless attr_md.java_property?
      rdr, wtr = attr_md.property_accessors
      pxy = obj.send(rdr)
      logger.debug { "Setting #{obj.qp} template #{template.qp} proxy owner to #{pxy}..." }
      template.send(wtr, pxy)
    end

    # Augment {CaRuby::Database::Writer#create_object} to work around caTissue bugs.
    # @quirk caTissue Bug #124: SCG SpecimenEventParameters save fails validation.
    #   Work-around is to create the SEP by updating the SCG.
    # @quirk If obj is a CaTissue::Specimen with the is_available flag set to false, then work around the bug
    #   described in {#create_unavailable_specimen}.
    # @quirk caTissue Bug #161: Specimen API disposal not reflected in result activity status.
    #   DisposalEventParameters create sets the owner Specimen activity_status to +Closed+ as a side-effect.
    #   Reflect this side-effect in the submitted DisposalEventParameters owner Specimen object.
    # Pass through an {Annotation::Proxy} to the referenced annotations.
    #
    # @param [Resource] obj the dependent domain object to save
    def create_object(obj)
     if collectible_event_parameters?(obj) then
        save_collectible_event_parameters(obj)
      elsif CaTissue::Specimen === obj then
        obj.add_defaults
        if obj.is_available == false or obj.available_quantity.zero? then
          # Note that the obj.is_available == false test is required as opposed to obj.is_available?,
          # since a nil is_available flag does not imply an unavailable specimen.
          return create_unavailable_specimen(obj) { super }
        end
      end
      
      # standard create
      super
      
      # replicate caTissue create side-effects in the submitted object
      if CaTissue::DisposalEventParameters === obj then
        obj.specimen.activity_status = 'Closed'
        logger.debug { "Set the created DisposalEventParameters #{obj.qp} owner #{obj.specimen.qp} activity status to Closed." }
      end
      
      obj
    end
    
    # Overrides {CaRuby::Database#create_from_template} as follows:
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
    # Cannot create a Specimen with any of the following conditions:
    # * zero available_quantity
    # * is_available flag set to false
    # * activity_status is +Closed+
    #
    # The work-around is to set the flags to true and +Active+, resp., set the quantities
    # to a non-zero value, create the Specimen and then update the created Specimen with
    # the original values.
    #
    # If the specimen has a disposal event, then this work-around interacts with the
    # {#save_changed_dependents} work-around as follows:
    # * Delete that event from the Specimen.
    # * Create the Specimen as described above.
    # * Update the Specimen as described above, but do not set the activity_status to +Closed+.
    # * Create the pending disposal event.
    #
    # @param [CaTissue::Specimen] specimen the specimen to create
    def create_unavailable_specimen(specimen)
      logger.debug { "Resetting #{specimen} quantities and available flag temporarily to work around caTissue Bug #160..." }
      specimen.is_available = true
      oiqty = specimen.initial_quantity
      oaqty = specimen.available_quantity
      ostatus = specimen.activity_status
      specimen.initial_quantity = 1.0
      specimen.available_quantity = 1.0
      specimen.activity_status = 'Active'
      # Cannot reset a disposed Specimen quantity, so postpone disposal until
      # quantities are reset. 
      dsp = specimen.specimen_events.detect { |sep| CaTissue::DisposalEventParameters === sep }
      if dsp then
        specimen.specimen_events.delete(dsp)
      end

      # delegate to standard create
      yield

      logger.debug { "Reupdating created #{specimen} with initial quantity and available flag set back to original values to complete caTissue Bug #160 work-around..." }
      specimen.is_available = false
      specimen.initial_quantity = oiqty
      # the available quantity is always zero, since the available flag is set to false
      specimen.available_quantity = 0.0
      # Leave status Active if there is a disposal event, since quantities cannot be reset
      # on a closed Specimen and creating the disposal event below will close the Specimen.
      specimen.activity_status = ostatus unless dsp
      update(specimen)
      
      # Finally, create the disposal event if one is pending.
      if dsp then
        specimen.specimen_events << dsp
        create(dsp)
      end
      
      logger.debug { "#{specimen} caTissue Bug #160 work-around completed." }
      specimen
    end

    # Overrides {CaRuby::Database::Reader#fetch_object} to circumvent {Annotation} fetch, since an annotation
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
    # @param [Attribute] attr_md the candidate attribute metadata
    # @return [Boolean] whether the attribute should not be included in the create template
    def exclude_pending_create_attribute?(obj, attr_md)
      attr_md.type < Annotation or super
    end
      
    # Override {CaRuby::Database#query_safe} to work around the following +caTissue+ bugs:
    # * @quirk caTissue Specimen auto-generates blank ExternalIdentifier.
    #     cf. https://cabig-kc.nci.nih.gov/Biospecimen/forums/viewtopic.php?f=19&t=436&sid=ef98f502fc0ab242781b7759a0eaff36
    # * @quirk caTissue Specimen auto-generates blank PMI. 
    def query_safe(obj_or_hql, *path)
      if path.last == :external_identifiers then
        CaTissue::Specimen.remove_empty_external_identifier(super)
      elsif path.last == :participant_medical_identifiers then
        CaTissue::Specimen.remove_empty_medical_identifier(super)
      else
        super
      end
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
      attr_md = obj.class.attribute_metadata(attribute)
      attr_md.declarer < Annotatable and attr_md.type < Annotation::Proxy
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
    
    # @quirk caCORE Override {CaRuby::Database::Reader#invertible_query?} to enable the Bug #147 work
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