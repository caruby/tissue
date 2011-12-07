module CaTissue
  # Declares the classes modified for migration.
  shims Participant

  class Participant::Clinical::NewDiagnosisHealthAnnotation
    # Makes a non-PHI date field from the year input value.
    #
    # @param [Integer] year the diagnosis year
    # @param row (see CaRuby::Migratable#migrate)
    # @return [Date] July 2 of the given year
    def migrate_date_of_examination(year, row)
      Date.new(year, 7, 2)
    end
  end
end