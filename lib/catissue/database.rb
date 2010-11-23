require 'singleton'
require 'caruby/util/topological_sync_enumerator'
require 'caruby/database'
# TODO - enable DE annotator
#require 'catissue/database/annotation/annotator'
require 'catissue/domain/scg_event_parameters'

module CaTissue
  # A CaTissue::Database mediates access to the caTissue database.
  # The CaRuby::Database functionality is preserved and not expanded, but this CaTissue::Database overrides
  # several base class private methods to enable alternate CaTissue-specific search strategies and work
  # around caTissue and caCORE bugs.
  class Database < CaRuby::Database
    include Singleton

    # The application service name
    SERVICE_NAME = 'catissuecore'

    # The default database name
    DEF_DATABASE_NAME = 'catissue'

    # Creates a new Database with the {SERVICE_NAME} service and {CaTissue.access_properties}.
    def initialize
      super(SERVICE_NAME, CaTissue.access_properties)
    end

    private

    def specimen_compatible?(target, source)
      target.class === source and
      specimen_parent_compatible?(target, source) and
      (target.specimen_type == source.specimen_type or source.specimen_type == 'Not Specified') and
      (target.pathological_status == source.pathological_status or source.pathological_status == 'Not Specified')
    end

    def specimen_parent_compatible?(target, source)
      if target.parent then
        source.parent and source.parent.identifier == target.parent.identifier
      else
        source.parent.nil?
      end
    end

    # This method patches up fetched sources to correct the following anomaly:
    #
    # caCORE alert - fetched references are not reconciled within an existing query result, e.g.
    # given a query result with two Specimens s1 and s2, the parent reference is not fetched.
    # Subsequently fetching the parent is independent of the query result. Thus if s1 is the parent
    # of s2 in the database, the fetched s2 parent s3 is distinct from s1, even though
    # s1.identifier == s3.identifier. Thus, enforcing reference consistency requires a post-fetch step
    # that matches the fetched objects to the original query result on identifier and resets the
    # references.
    def resolve_parent(refs, attribute)
      id_ref_hash = refs.to_compact_hash { |ref| ref.identifier }.invert
      refs.each do |ref|
        parent = ref.send(attribute) || next
        resolved = id_ref_hash[parent.identifier] || next
        logger.debug { "Resetting #{ref.qp} #{attribute} from #{parent} to #{resolved} in order to fix a caCORE inconsistency..." }
        ref.set_attribute(attribute, resolved)
      end
    end

    # Work around the following caTissue bugs:
    # * caTissue alert - Bug #135: Update SCG SpecimenEventParameters raises AuditException.
    #   Work around is to update the SCG instead.
    #
    # @param (see CaRuby::Database#update_object)
    # @return (see CaRuby::Database#update_object)
    def update_object(obj)
      if scg_event_parameters?(obj) then
        update_scg_event_parameters(obj)
      else
        if CaTissue::Specimen === obj
          # Specimen activity status is not always set to default; don't know why.
          # TODO - isolate and fix at source
          obj.activity_status ||= 'Active'
        end
        super
      end
    end

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
    
    # Returns whether operation is the second SCG Update described in {#recursive_save?}.
    def scg_event_update_workaround?(obj, operation)
      return false unless CaTissue::SpecimenCollectionGroup == obj and operation == :update
      last = @operations.last
      return false unless last and scg_event_parameters?(last.subject)
      ev = last.subject
      return false unless ev.specimen_collection_group == obj
      penultimate = @operations[-2]
      penultimate and penultimate.subject == obj
    end
      
    # Augments {CaRuby::Database#save_with_template} to work around the following caTissue anomalies:
    #
    # caTissue alert - Bug #149: API update TissueSpecimen position validation incorrect.
    # The Specimen update argument must reference the old position, even though the position is not
    # updatable, unless old status is Pending. The validation defect described in Bug #149 requires
    # a work-around that is also used for a different reason described in the following paragraph.
    #
    # caTissue alert - Update of a {CaTissue::Specimen} which references a position must include the former
    # position in the caTissue service update argument. A Specimen position is altered as a side-effect
    # by creating a proxy save {CaTissue::TransferEventParameters}. The changed position is not reflected
    # in the Specimen position, which must be refetched to reflect the database state. This fetch is
    # done automatically by {CaRuby::Database} as part of the save proxy mechanism. The Specimen update
    # template must include a reference to the former position but not the changed position.
    #
    # However, the Specimen {CaRuby::Writer#update} argument will include the changed position, not the
    # former position. The template built {CaRuby::Writer#update} for submission to the caTissue app
    # does not include a position reference, since the position has a save proxy which handles position
    # change as part of the {CaRuby::Writer} update dependent propagation.
    #
    # Thus, updating a Specimen which includes a position change is performed as follows:
    # * reconstitute the former position from the Position snapshot taken as part of the
    #    {CaRuby::Persistable} change tracker.
    # * add the former position to the template (which will now differ from the {CaRuby::Writer#update}
    #   argument).
    # * submit the adjusted Specimen template to the caTissue app updateObject.
    # * {CaRuby::Writer#update} will propagate the Specimen update to the changed position dependent,
    #   which in turn saves via the {CaTissue::TransferEventParameters} proxy.
    # * The proxy save will in turn refetch the proxied Specimen position to obtain the identifier
    #   and merge this into the Specimen position.
    # * The Specimen update template is used solely to satisfy the often arcane caTissue interaction
    #   requirements like this work-around, and is thrown away along with its aberrant state.
    #
    # This work-around is the only case of a save template modification to handle a caTissue special
    # case. Note that the {CaTissue::SpecimenPosition} logic does not apply to a
    # {CaTissue::ContainerPosition}, which can be updated directly.
    #
    # The additional complexity of this work-around is necessitated by the caTissue policy of update
    # by indirect server-side side-effects that are not reflected back to the client. The caRuby
    # policy of a declarative API that persists the save argument as given and reflects the
    # changed database state requires this work-around.
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
    
    # @return [Boolean] whether obj is a SCGEventParameters with a SCG owner
    def scg_event_parameters?(obj)
      SCGEventParameters === obj and obj.specimen_collection_group
    end

    # @param [SCGEventParameters] ep the SCG event parameters to update
    # @return (see CaRuby::Database#update_object)
    def update_scg_event_parameters(ep)
      scg = ep.specimen_collection_group
      logger.debug { "Work around #{ep.qp} caTissue SCG SpecimenEventParameters update bug by updating the owner #{scg.qp} instead..." }
      ensure_exists(scg)
      # update the SCGEventParameters by updating the SCG
      update(scg)
      raise CaRuby::DatabaseError.new("Update SCG did not cascade to dependent #{ep}") unless ep.identifier
      ep
    end
    
    # Overrides {CaRuby::Database::Writer#save_dependents} to handle the work-around described
    # in {#save_specimen_dependents}.
    #
    # @param (see CaRuby::Writer#save_dependents)
    def save_dependents(obj)
      Specimen === obj ? save_specimen_dependents(obj) { super } : super
    end
    
    # Overrides {CaRuby::Database::Writer#save_dependents} on a Specimen to correct the
    # following problem:
    #
    # caTissue alert - DisposalEventParameters must be created after all other Specimen SEPs.
    #
    # The process for migrating a discarded Specimen is as follows:
    # * Create the Specimen with status Active.
    # * Create the non-disposal events.
    # * Create the DisposalEventParameters.
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
    # @yield [dependent] calls the base {CaRuby::Writer#save_dependents} 
    # @yieldparam [Resource] dependent the dependent to save
    def save_specimen_dependents(specimen)
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

    # Overrides {CaRuby::Database::Writer#save_with_template} to work around the following
    # caTissue bugs:
    # * caTissue alert - Bug TODO: CollectionProtocolRegistration must cascade through
    #   CP, but the CP events cannot cascade to SpecimenRequirement without raising an
    #   Exception. Work-around is to clear the template CP events.
    # * caTissue alert - Bug #164: Update Specimen with unchanged ExternalIdentifier fails.
    #   Work-around is to clear the update template external_identifiers.
    def save_with_template(obj, template)
      if CaTissue::CollectionProtocolRegistration === obj and template.collection_protocol then
        template.collection_protocol.collection_protocol_events.clear
      elsif obj.identifier and CaTissue::Specimen === obj
        sv_eids = obj.external_identifiers.select { |eid| eid.changed? }
        unless sv_eids.empty? then
          logger.debug { "Work around caTissue Bug #164 by updating the #{obj.qp} changed external_identifiers separately: #{sv_eids.qp}." }
          sv_eids.each { |eid| eid.identifier ? update(eid) : create(eid) }
        end
        logger.debug { "Work around caTissue Bug #164 by setting the #{obj.qp} update template #{template.qp} external_identifiers to nil." }
        template.external_identifiers = nil
      end
      super
    end

    # Augment {CaRuby::Database::Writer#create_object} for the following work-arounds:
    # * caTissue alert - Bug #124: SpecimenEventParameters with SCG rather than Specimen fails validation.
    #   Work-around is to create the SEP with the specimen set to a SCG specimen, then unset the
    #   specimen reference.
    # * if obj is a CaTissue::Specimen with the is_available flag set to false, then work around the bug
    #   described in {#create_unavailable_specimen}.
    # * caTissue alert - Bug #161: Specimen API disposal not reflected in result activity status.
    #   DisposalEventParameters create sets the owner Specimen activity_status to +Closed+ as a side-effect.
    #   Reflect this side-effect in the submitted DisposalEventParameters owner Specimen object.
    def create_object(obj)
#      if CaTissue::SCGEventParameters === obj and obj.specimen_collection_group then
#        return create_scg_event_parameters(obj) { super }
#      elsif CaTissue::Specimen === obj and obj.is_available == false then
      if CaTissue::Specimen === obj and not obj.available? then
        # Note that the obj.is_available == false test is required as opposed to obj.is_available?,
        # since a nil is_available flag does not imply an unavailable specimen.
        return create_unavailable_specimen(obj) { super }
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

    # Creates the given specimen by working around the following bug:
    #
    # caTissue alert - Bug #160: Missing Is Available? validation.
    # Cannot create a Specimen with any of the following conditions:
    # * zero available_quantity
    # * is_available flag set to false
    # * activity_status is +Closed+
    #
    # The work-around is to set the flags to true and +Active+, resp., set the quantities
    # to a non-zero value, create the Specimen and then update the created Specimen with
    # the original values.
    #
    # If spc has a disposal event, then this work-around interacts with the {#save_dependents}
    # work-around as follows:
    # * delete that event from the Specimen.
    # * Create the Specimen as described above.
    # * Update the Specimen as described above, but do no set the activity_status to +Closed+.
    # * Create the pending disposal event.
    #
    # @param [CaTissue::Specimen] specimen the specimen to create
    def create_unavailable_specimen(specimen)
      logger.debug { "Resetting #{specimen} quantities and available flag temporarily to work around caTissue Bug #160..." }
      specimen.is_available = true
      oiqty = specimen.initial_quantity
      oaqty = specimen.available_quantity
      ostatus =  specimen.activity_status
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

    def fetch_object(obj)
      super or fetch_alternative(obj)
    end

    def fetch_alternative(obj)
      case obj
      when CaTissue::Specimen then
        fetch_specimen_alternative(obj)
      when CaTissue::Participant then
        fetch_participant_alternative(obj)
      end
    end
      
    # Override {CaRuby::Database#query_safe} to work around the following +caTissue+ bugs:
    # * caTissue alert - Specimen auto-generates blank ExternalIdentifier.
    #   cf. https://cabig-kc.nci.nih.gov/Biospecimen/forums/viewtopic.php?f=19&t=436&sid=ef98f502fc0ab242781b7759a0eaff36
    # * caTissue alert - Specimen auto-generates blank PMI. 
    def query_safe(obj_or_hql, *path)
      if path.last == :external_identifiers then
        CaTissue::Specimen.remove_empty_external_identifier(super)
      elsif path.last == :participant_medical_identifiers then
        CaTissue::Specimen.remove_empty_medical_identifier(super)
      else
        super
      end
    end

    # caTissue alert - Bug #147: SpecimenRequirement query ignores CPE.
    # Work around this bug by an inverted query on the referenced CPE.
    def query_object(obj, attribute=nil)
      if CaTissue::SpecimenRequirement === obj and not obj.identifier and obj.collection_protocol_event then
        query_requirement_using_cpe_inversion(obj, attribute)
      else
        super
      end
    end

    # caCORE alert - Override {CaRuby::Database::Reader#invertible_query?} to enable the Bug #147 work
    # around in {#query_object}. Invertible queries are performed to work around Bug #79. However, this
    # work-around induces Bug #147, so we disable the Bug #79 work-around here for the special case of
    # a CPE in order to enable the Bug #147 work-around. And so it goes....
    def invertible_query?(obj, attribute)
      super and not (CaTissue::CollectionProtocolEvent === obj and attribute == :specimen_requirements)
    end

    # Returns the Annotation::Annotator service for klass, or nil if klass is neither annotatable nor an annotation.
    def annotation_service(klass)
      # create the single annotator on demand
      @annotator ||= CaTissue::Annotation::Annotator.new(self)
      # find the service or return nil if kla
      @annotator.service(klass)
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
      mid = pnt.medical_identifiers.first
      return if mid.nil?
      logger.debug { "Using alternative Participant fetch strategy to find Participant by medical record number..." }
      return unless exists?(mid)
      candidates = query(mid.copy, :participant)
      candidates.first if candidates.size == 1
    end

    # Returns a fetched Specimen which matches spc on at least one external identifier, or nil if no match.
    def fetch_specimen_alternative(spc)
      eid = spc.external_identifiers.detect { |eid| eid.identifier } || spc.external_identifiers.first || return
      logger.debug { "Using alternative Specimen fetch strategy to find #{spc} by external identifier #{eid}..." }
      candidates = query(eid.copy, :specimen)
      candidates.first if candidates.size == 1
    end

    def query_scg_specimens_using_specimen_reference(scg)
      spc = CaTissue::Specimen.new(:specimen_collection_group => scg.copy)
      logger.debug { "Using alternative SCG specimens query strategy to find Specimens by Specimen SCG reference #{scg.qp}..." }
      query(spc)
    end

    def query_requirement_using_cpe_inversion(rqmt, attribute)
      cpe = rqmt.collection_protocol_event
      logger.debug { "Using alternative SpecimenRequirement query strategy to find SpecimenRequirements by inverted CPE reference #{cpe}..." }
      path = [:specimen_requirements]
      path << attribute if attribute
      query(cpe, *path)
    end
  end
end