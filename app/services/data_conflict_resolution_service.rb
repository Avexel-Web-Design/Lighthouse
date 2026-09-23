class DataConflictResolutionService
  def initialize(conflict, resolution_value:, resolved_by:, approved_entry_id: nil)
    @conflict = conflict
    @resolution_value = resolution_value
    @resolved_by = resolved_by
    @approved_entry_id = approved_entry_id
  end

  def resolve!
    raise ArgumentError, "Resolution value can't be blank" if @resolution_value.blank?

    ActiveRecord::Base.transaction do
      apply_resolution_to_entries!
      apply_optional_approval!
      @conflict.update!(
        resolved: true,
        resolved_by: @resolved_by,
        resolution_value: serialized_resolution_value
      )
    end

    RefreshSummariesJob.perform_later(@conflict.event_id)
    @conflict
  end

  private

  def apply_resolution_to_entries!
    typed_value = typed_resolution_value

    conflict_entries.find_each do |entry|
      next if entry.rejected?

      entry.update!(data: entry.data.merge(@conflict.field_name => typed_value))
    end
  end

  def apply_optional_approval!
    return unless @approved_entry_id.present?

    approved_entry = conflict_entries.find_by(id: @approved_entry_id)
    return if approved_entry.blank?

    unless approved_entry.flagged?
      raise ArgumentError, "Only flagged entries can be admin approved"
    end

    approved_entry.update!(status: :approved)
  end

  def conflict_entries
    @conflict_entries ||= ScoutingEntry.where(
      event_id: @conflict.event_id,
      frc_team_id: @conflict.frc_team_id,
      match_id: @conflict.match_id
    )
  end

  def typed_resolution_value
    sample_values = Array(@conflict.values&.values).compact

    if boolean_values?(sample_values)
      ActiveModel::Type::Boolean.new.cast(@resolution_value)
    elsif numeric_values?(sample_values)
      cast_numeric(@resolution_value)
    else
      @resolution_value.to_s
    end
  end

  def serialized_resolution_value
    # Store the raw user input verbatim. Using typed_resolution_value.to_s here
    # would lose information (e.g. boolean "1" casts to true, then serializes
    # as "true"), while entries still receive the correctly typed value.
    @resolution_value.to_s
  end

  def boolean_values?(values)
    values.any? && values.all? do |value|
      [ true, false ].include?(value) || value.to_s.in?(%w[true false 1 0])
    end
  end

  def numeric_values?(values)
    values.any? && values.all? { |value| value.to_s.match?(/\A-?\d+(\.\d+)?\z/) }
  end

  def cast_numeric(value)
    numeric = value.to_s
    numeric.include?(".") ? numeric.to_f : numeric.to_i
  end
end
