require 'caruby/util/inflector'
require 'caruby/util/uniquifier'
require 'caruby/util/validation'
require 'catissue/util/storable'

module CaTissue
  # import the Java class
  java_import('edu.wustl.catissuecore.domain.Specimen')

  # The Specimen domain class.
  class Specimen
    include Validation, Storable, Resource
    
    # caTissue alert - Bug #64: Some domain collection properties not initialized.
    # Initialize consent_tier_statuses if necessary. 
    #
    # @return [Java::JavaUtil::Set] the statuses
    def consent_tier_statuses
      getConsentTierStatusCollection or (self.consent_tier_statuses = Java::JavaUtil::LinkedHashSet.new)
    end

    # Sets the barcode to the given value. This method converts an Integer to a String.
    def barcode=(value)
      value = value.to_s if Integer === value
      setBarcode(value)
    end

    add_attribute_aliases(:requirement => :specimen_requirement, :position => :specimen_position)

    add_attribute_defaults(:activity_status => 'Active', :collection_status => 'Collected')

    add_mandatory_attributes(:initial_quantity, :available_quantity)

    set_secondary_key_attributes(:label)

    # The Specimen-SpecimenRequirement association is bi-directional.
    set_attribute_inverse(:specimen_requirement, :specimens)

    # Specimen children are constrained to Specimen.
    set_attribute_type(:child_specimens, Specimen)

    # Specimen parent is constrained to Specimen.
    set_attribute_type(:parent_specimen, Specimen)

    # Even though the inverse is declared in AbstractSpecimen, do so again here to
    # ensure that there is no order dependency of the dependent declaration below
    # on AbstractSpecimen metadata initialization.
    set_attribute_inverse(:parent_specimen, :child_specimens)
    
    # A child Specimen is auto-generated from a SpecimenRequirement template if it
    # is part of a hierarchy built by SCG create. Unlike SpecimenRequirement,
    # Specimen children are cascaded.
    add_dependent_attribute(:child_specimens, :autogenerated, :no_cascade_update_to_create)

    # caTissue alert - Specimen consent_tier_statuses is cascaded but not fetched.
    add_dependent_attribute(:consent_tier_statuses, :unfetched)

    # caTissue alert - Bug #163: ExternalIdentifer not fetched with Specimen in API.
    # Although the caTissue 1.1.2 Hibernate config specifies that external_identifiers
    # are cascaded and fetched with the owner Specimen, they are not fetched with
    # the owner Specimen. Work-around is to marked them as a unfetched.
    #
    # caTissue has complicated undocumented logic for updating external identifiers
    # in NewSpecimenBizLogic.setExternalIdentifier
    add_dependent_attribute(:external_identifiers, :unfetched)

    # caTissue alert - Specimen position update is cascaded in Hibernate, but updateObject
    # is precluded by the caTissue business logic. Position change is performed by a
    # TransferEventParameters proxy instead. SpecimenPosition work-around is to
    # designate a save proxy.
    add_dependent_attribute(:specimen_position)

    # Although label is the key, it is auto-generated if not provided in the create.
    qualify_attribute(:label, :optional)

    # The available flag is set on the server.
    qualify_attribute(:is_available, :volatile)

    # Oddly, the seldom-used biohazards are fetched along with Specimen.
    qualify_attribute(:biohazards, :fetched)

    # caTissue alert - the Specimen parent_changed flag is ignored in a caCORE update
    # or create Specimen argument and is set on the server. Mark the attribute as unsaved.
    qualify_attribute(:parent_changed, :unsaved)

    # caTissue alert - Bug #159: Update pending Specimen ignores availableQuantity.
    # available_quantity is not reflected in the caCORE create or update result.
    # This is true even though the caTissue GUI supports available_quantity update.
    # Work-around is to set the :autogenerated flag, which will refetch a saved Specimen
    # and reupdate the Specimen if the stored available_quantity differs from the save
    # argument.
    qualify_attribute(:available_quantity, :autogenerated)

    # Specimen storage is constrained on the basis of the +specimen_class+.
    alias :storable_type :specimen_class

    def initialize(params=nil)
      super
      # work around caTissue Bug #64
      self.consent_tier_statuses ||= Java::JavaUtil::LinkedHashSet.new
    end

    # Overrides {Resource#owner} to return the parent_specimen, if it exists, or the specimen_collection_group otherwise.
    def owner
      parent_specimen or specimen_collection_group
    end
    
    # @return [Boolean] whether this Specimen collection status is +Pending+
    def pending?
      collection_status == 'Pending'
    end
    
    # @return [Boolean] whether this Specimen collection status is +Collected+
    def collected?
      collection_status == 'Collected'
    end
    
    def merge_attribute_value(attribute, oldval, newval)
      # caTissue alert - remove the autogenerated blank ExternalIdentifier.
      # @see https://cabig-kc.nci.nih.gov/Biospecimen/forums/viewtopic.php?f=19&t=436&sid=ef98f502fc0ab242781b7759a0eaff36
      # @see CaTissue::Database#query_safe
      if attribute == :external_identifiers and newval then
        CaTissue::Specimen.remove_empty_external_identifier(newval)
      end
      super
    end

#    # Restores this disposed Specimen by deleting the DisposalEventParameters and resetting the availability and activity status.
#    # Returns the deleted DisposalEventParameters, or nil if none.
#    def recover
#      # TODO - test this
#      dep = event_parameters.detect { |ep| CaTissue::DisposalEventParameters === ep }
#      return if dep.nil?
#      dep.delete
#      self.available = true
#      self.activity_status = 'Active'
#      update
#    end

    # Override default {CaRuby::Resource#merge_attributes} to ignore a source SpecimenRequirement parent_specimen.
    def merge_attributes(other, attributes=nil)
      case other
      when SpecimenRequirement then
        # merge with the default requirement merge attributes if necessary
        attributes ||= MERGEABLE_RQMT_ATTRS
        super(other, attributes)
        # copy the requirement characteristics
        sc = other.specimen_characteristics
        self.specimen_characteristics ||= sc.copy(MERGEABLE_SPC_CHR_ATTRS) if sc
      when Hash then
        # the requirement template
        rqmt = other[:specimen_requirement] || other[:requirement]
        # merge the attribute => value hash
        super
        # merge the SpecimenRequirement after the hash
        merge_attributes(rqmt) if rqmt
      else
        super
      end
      self
    end

    # Raises a ValidationError when one the following conditions holds:
    # * a top-level Specimen does not have a SGC
    # * the available_quantity exceeds the initial_quantity
    # * the availability flag is set and the available_quantity is zero
    #
    # caTissue alert - Bug #160: Missing Is Available? validation.
    # Updating Specimen with the availablity flag set and available_quantity zero
    # silently leaves the availablity flag unset.
    def validate
      super
      if parent.nil? and specimen_collection_group.nil? then
        raise ValidationError.new("Top-level specimen #{self} is missing specimen collection group")
      end
      if available_quantity and initial_quantity and available_quantity > initial_quantity then
        raise ValidationError.new("#{self} available quantity #{available_quantity} cannot exceed initial quantity #{initial_quantity}")
      end
      if available? and available_quantity.zero? then
        raise ValidationError.new("#{self} availablility flag cannot be set when the avaialble quantity is zero")
      end
      if collected? then
        unless event_parameters.detect { |ep| CaTissue::CollectionEventParameters === ep } then
          raise ValidationError.new("#{self} is missing CollectionEventParameters")
        end
        unless event_parameters.detect { |ep| CaTissue::ReceivedEventParameters === ep } then
          raise ValidationError.new("#{self} is missing ReceivedEventParameters")
        end
      end
    end

    # Returns the Specimen in others which matches this Specimen in the scope of an owner SCG.
    # This method relaxes {CaRuby::Resource#match_in_owner_scope} to include a match on at least
    # one external identifier.
    def match_in_owner_scope(others)
      super or others.detect do |other|
         external_identifiers.any? do |eid|
           other.external_identifiers.detect { |oeid| eid.name == oeid.name and eid.value == oeid.value }
         end
      end
    end

    # @return the SpecimenPosition class which this Specimen's Storable can occupy
    def position_class
      CaTissue::SpecimenPosition
    end

    # @return this Specimen +position+ Location
    def location
      position.location if position
    end
    
    # Creates a new Specimen or CaTissue::SpecimenRequirement from the given symbol => value params hash.
    #
    # The default class is inferred from the _class_ parameter, if given, or inherited
    # from this parent specimen otherwise. The inferred class is the camel-case parameter value
    # with +Specimen+ appended, e.g. :tissue => +TissueSpecimen+. This class name is resolved to
    # a class in the CaTissue module context.
    #
    # The supported :type parameter value includes the permissible caTissue specimen type String
    # values as well as the shortcut tissue type symbols :fresh, :fixed and :frozen.
    #
    # If a SpecimenRequirement parameter is provided, then that SpecimenRequirement's attribute
    # values are merged into the new Specimen after the other parameters are merged. Thus, params
    # takes precedence over the SpecimenRequirement.
    #
    # If the :count parameter is set to a number greater than one, then the specimen is aliquoted
    # into the specified number of samples.
    #
    # This method is a convenience method to create either a Specimen or CaTissue::SpecimenRequirement.
    # Although CaTissue::SpecimenRequirement is a direct CaTissue::AbstractSpecimen subclass rather than
    # a Specimen subclass, the create functionality overlaps and Specimen is the friendlier
    # class to define this utility method as opposed to the more obscure CaTissue::AbstractSpecimen.
    #
    # @param [<{Symbol => Object}>] params the create parameter hash. Besides the listed params options,
    #   this hash can include additional target Specimen attribute => value entries for any supported
    #   Specimen Java property attribute
    # @option params [Symbol, String, Class] :class the required target specimen class,
    #   e.g. :molecular, +TissueSpecimen+ or CaTissue::TissueSpecimen
    # @option params [Symbol, String, Class] :type the optional target specimen type symbol or string,
    #   e.g. :frozen or +Frozen Tissue Block+
    # @option params [Numeric] :quantity the optional target specimen intial quantity
    # @option params [CaTissue::SpecimenRequirement] :requirement the optional requirement with additional
    #   target attribute values
    # @raise [ArgumentError] if the specimen class option is not recognized
    def self.create_specimen(params)
      raise ArgumentError.new("Specimen create params argument type unsupported: #{params.class}") unless Hash === params
      # standardize the class, type and quantity params
      spc_cls = params.delete(:class)
      params[:specimen_class] ||= spc_cls if spc_cls
      spc_type = params.delete(:type)
      params[:specimen_type] ||= spc_type if spc_type
      qty = params.delete(:quantity)
      params[:initial_quantity] ||= qty if qty

      # the specimen_class as a Class, Symbol or String
      cls_opt = params[:specimen_class]
      # standardize the specimen_class parameter as a permissible caTissue value
      standardize_class_parameter(params)
      # if the specimen_class was not specified as a Class, then infer the specimen domain class from the
      # parameter prefix and Specimen suffix
      if Class === cls_opt then
        klass = cls_opt
      else
        class_name = params[:specimen_class] + 'Specimen'
        klass = CaTissue.domain_type_with_name(class_name)
        raise ArgumentError.new("Specimen class #{class_name} is not recognized for parameter #{cls_opt}") if klass.nil?
      end
      
      # add a default available quantity to a Specimen but not a SpecimenRequirement
      params[:available_quantity] ||= params[:initial_quantity] if klass <= self

      # make the specimen
      klass.new(params)
    end

    # Convenience method which returns the SCG collection protocol.
    #
    # @return [CaTissue::CollectionProtocol] the SCG collection protocol
    def collection_protocol
      specimen_collection_group.collection_protocol
    end

    # Withdraws consent for this Specimen.
    #
    # _Experimental_. TODO - test this method.
    #
    # If a consent_tier is provided, then the SCG CaTissue::ConsentTierStatus with this consent tier is withdrawn.
    # Otherwise, if there is a single SCG CaTissue::ConsentTierStatus, then that consent tier is withdrawn.
    # Otherwise an exception is thrown.
    #
    # @param [CaTissue::ConsentTier, nil] optional consent tier of the SCG CaTissue::ConsentTierStatus to withdraw
    # @raise [ValidationError] if an unambiguous SCG CaTissue::ConsentTierStatus to withdraw could not be determined
    def withdraw_consent(consent_tier=nil)
      statuses = specimen_collection_group.consent_tier_statuses
      status = if consent_tier then
        statuses.detect { |cts| cts.consent_tier.identifier == consent_tier.identifier } or
        raise ValidationError.new("SCG #{specimen_collection_group} consent status not found for consent '#{consent_tier.statement}'")
      elsif specimen_collection_group.consent_tier_statuses.size == 1 then
        statuses.first
      elsif specimen_collection_group.consent_tier_statuses.size == 0 then
        raise ValidationError.new("Specimen #{self} SCG does not have a consent tier status")
      else
        raise ValidationError.new("Specimen #{self} SCG consent tier is ambiguous:#{consent_tier_statuses.select { |cts| "\n  #{cts.statement}" }.to_series('or')}")
      end
      ct = status.consent_tier
      cts = consent_tier_statuses.detect { |item| item.consent_tier == ct }
      consent_tier_statuses << cts = ConsentTierStatus.new(:consent_tier => ct) if cts.nil?
      cts.status = 'Withdrawn'
    end
    
    # Permanently dispose of this specimen by creating a CaTissue::DisposalEventParameters with
    # status 'Closed' and the optional reason.
    def dispose(reason=nil)
      CaTissue::DisposalEventParameters.new(:specimen => self, :reason => reason)
    end
    
    protected

    def self.remove_empty_external_identifier(eids)
      bogus = eids.detect { |eid| eid.name.nil? }
      if bogus then
        logger.debug { "Work around caTissue bug by removing empty fetched #{bogus.specimen.qp} #{bogus.qp} from #{eids.qp}..." }
        # dissociate the specimen
        bogus.specimen = nil
        # remove the bogus eid
        eids.delete(bogus)
      end
      eids
    end

    private

    MERGEABLE_RQMT_ATTRS = nondomain_java_attributes - primary_key_attributes

    MERGEABLE_SPC_CHR_ATTRS = SpecimenCharacteristics.nondomain_java_attributes - SpecimenCharacteristics.primary_key_attributes

    # Adds this Specimen's defaults, as follows:
    # * The default specimen_collection_group is the parent specimen_collection_group.
    # * Add default collection and received event parameters if this Specimen is collected.
    # * If the is_available flag is set to false then the default available quantity is
    #   zero, otherwise the default available quantity is the initial quantity.
    # * The default is_available flag is true if the available quantity is greater than zero.
    #
    # The motivation for the is_available flag default is that an initial quantity of zero can indicate
    # unknown amount as well a known zero amount, and therefore the available flag should be set to
    # false only if it is known that there was an amount but that amount is exhausted.
    #
    # caTissue alert - initial_quantity cannot be null (cf. Bug #160).
    #
    # caTissue alert - the default available status must be left nil rather than set to false, since
    # caTissue allows a nil available status on insert but not a false value, even though a nil status
    # is set to false (0 database value) when the record is inserted.
    #
    # caTissue alert - a collected Specimen without a collection and received event parameters
    # results in the dreaded 'Severe Error' server message. TODO - isolate and report.
    def add_defaults_local
      super
      self.specimen_collection_group ||= parent.specimen_collection_group if parent
      add_default_event_parameters
      
      # The default available quantity is the initial quantity.
      aq = available_quantity
      if aq.nil? or aq.zero? then
        self.available_quantity = is_available == false ? 0.0 : initial_quantity
      end
      
      # The specimen is available by default if there is a positive available quantity.
      # If is_available is set to false, then set it to nil to work around a caTissue bug.
      self.is_available ||= available_quantity.zero? ? nil : true
    end
    
    # Adds the default collection and received event parameters if the collection status
    # is +Collected+.
    def add_default_event_parameters
      if collection_status == 'Collected' and specimen_collection_group then
        unless event_parameters.detect { |ep| CaTissue::CollectionEventParameters === ep } then
          CaTissue::CollectionEventParameters.new(:specimen => self, :user => specimen_collection_group.collector)
        end
        unless event_parameters.detect { |ep| CaTissue::ReceivedEventParameters === ep } then
          CaTissue::ReceivedEventParameters.new(:specimen => self, :user => specimen_collection_group.receiver)
        end
      end
    end

    # Sets the :specimen_class parameter to a permissible caTissue value.
    def self.standardize_class_parameter(params)
      opt = params[:specimen_class]
      if opt.nil? then
        rqmt = params[:specimen_requirement] || params[:requirement]
        if rqmt then
          rqmt.add_defaults unless rqmt.specimen_class
          opt = rqmt.specimen_class
        end
      end
      raise ArgumentError.new("Specimen class is missing from the create parameters") if opt.nil?
      # Convert the class option Symbol to a capitalized String without a class path prefix or the
      # Specimen[Requirement] suffix.
      params[:specimen_class] = opt.to_s[/(\w+?)(Specimen(Requirement)?)?$/, 1].capitalize_first
    end

    def set_aliquot_parameters(params, count)
      super
      # default available quantity
      self.available_quantity ||= initial_quantity
      # apportion the parent quantity
      params[:initial_quantity] ||= available_quantity / count
    end

    # Delegate to {AbstractSpecimen#create_derived} and add a default label if necessary. The default label
    # is this Specimen label appended with an underscore and the number of children, e.g. +TB-0023434_1+
    # for the first child of a parent with label +TB-0023434+.
    def create_derived(params)
      spc = super
      spc.label ||= "#{label}_#{children.size}" if label
      spc.specimen_collection_group = specimen_collection_group
      # if the derived specimen is the same type as this parent specimen,
      # then decrement this parent's quantity by the derived specimen amount
      decrement_derived_quantity(spc) if specimen_type == spc.specimen_type
      spc
    end

    def self.specimen_class_symbol_to_class(symbol)
      name = symbol.to_s
      class_name = name[0, 1].upcase + name[1..-1]
      suffix = 'Specimen'
      class_name << suffix unless class_name.rindex(suffix) == class_name.length - suffix.length
      CaTissue.domain_type_with_name(class_name) or raise ArgumentError.new("Specimen class #{class_name} is not recognized for specimen type parameter #{symbol}")
    end

#    def default_specimen_characteristics
#      return if specimen_collection_group.nil?
#      rqmts = specimen_collection_group.requirements
#      # match the requirement specimen type
#      rqmt = specimen_collection_group.requirements.detect { |rqmt| specimen_type == rqmt.specimen_type }
#      # fallback is match on requirement class and generic requirment specimen type
#      rqmt ||= specimen_collection_group.requirements.detect do |rqmt|
#        specimen_class === rqmt.specimen_class and rqmt.specimen_type.nil? or rqmt.specimen_type == 'Not Specified'
#      end
#      rqmt.specimen_characteristics.copy if rqmt
#    end

    # Decrements this parent's available quantity by the given child's initial quantity, if the specimen types are the same and there
    # are the relevant quantities.
    def decrement_derived_quantity(child)
      return unless specimen_type == child.specimen_type and child.initial_quantity
      if available_quantity.nil? then
        raise ValidationError.new("Derived specimen has an initial quantity #{child.initial_quantity} but the parent is missing an available quantity")
      elsif (available_quantity - child.initial_quantity).abs < 0.00000001 then
        # rounding error
        self.available_quantity = 0.0
      elsif child.initial_quantity <= available_quantity then
        self.available_quantity -= child.initial_quantity
      else
        raise ValidationError.new("Derived specimen initial quantity #{child.initial_quantity} exceeds parent available quantity #{available_quantity}")
      end
    end
  end
end