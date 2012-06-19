module CaTissue
  # Declares the classes modified for migration.
  shims Participant, SpecimenCollectionGroup

  class Participant
    # Extracts the Participant first name from the +Initials+ input field.
    def migrate_first_name(value, row)
      value[0, 1]
    end

    # Extracts the Participant last name from the +Initials+ input field.
    def migrate_last_name(value, row)
      value[-1, 1]
    end
  end

  class SpecimenCollectionGroup
    # Returns whether this SCG has a SPN.
    def migration_valid?
      surgical_pathology_number
    end
  end
end