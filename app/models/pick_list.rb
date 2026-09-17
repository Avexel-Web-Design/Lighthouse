class PickList < ApplicationRecord
  # Associations
  belongs_to :event
  belongs_to :user

  # Validations
  validates :name, presence: true
  validate :entries_belong_to_event

  before_validation :normalize_entries

  def ordered_team_ids
    scalar_mode = scalar_entry_mode(Array(entries))
    Array(entries).filter_map { |entry| extract_team_id(entry, scalar_mode: scalar_mode) }.uniq
  end

  def team_count
    ordered_team_ids.size
  end

  private

  def normalize_entries
    resolved = ordered_team_ids
    raw = Array(entries).reject(&:blank?)
    # Preserve raw invalid inputs so validation can report them
    # instead of silently dropping to empty (which would pass validation).
    return if raw.any? && resolved.empty?

    self.entries = resolved
  end

  def entries_belong_to_event
    return if event.blank?

    raw = Array(entries).reject(&:blank?)
    return if raw.empty?

    ordered = ordered_team_ids
    if ordered.empty?
      errors.add(:entries, "contain teams that are not part of the selected event")
      return
    end

    valid_ids = FrcTeam.at_event(event).where(id: ordered).pluck(:id)
    invalid_ids = ordered - valid_ids
    return if invalid_ids.empty?

    errors.add(:entries, "contain teams that are not part of the selected event")
  end

  def extract_team_id(entry, scalar_mode: nil)
    case entry
    when Integer
      team_id_from_scalar(entry, scalar_mode)
    when String
      team_id_from_scalar(entry.to_i, scalar_mode) if entry.match?(/\A\d+\z/)
    when Hash
      team_id_from_id(entry["id"] || entry[:id] || entry["team_id"] || entry[:team_id] || entry["frc_team_id"] || entry[:frc_team_id]) ||
        team_id_from_number(entry["team_number"] || entry[:team_number])
    end
  end

  def team_id_from_number(team_number)
    return if team_number.blank?

    team_scope.find_by(team_number: team_number.to_i)&.id
  end

  def team_id_from_scalar(value, scalar_mode)
    candidate = value.to_i
    return if candidate <= 0

    return team_id_from_number(candidate) if scalar_mode == :team_number

    team_id_from_id(candidate) || team_id_from_number(candidate)
  end

  def team_id_from_id(value)
    candidate = value.to_i
    return if candidate <= 0

    team_scope.find_by(id: candidate)&.id
  end

  def scalar_entry_mode(raw_entries)
    scalar_values = raw_entries.filter_map do |entry|
      case entry
      when Integer
        entry if entry.positive?
      when String
        entry.to_i if entry.match?(/\A\d+\z/)
      end
    end.uniq

    return :team_number if scalar_values.empty?

    id_matches = team_scope.where(id: scalar_values).count
    team_number_matches = team_scope.where(team_number: scalar_values).count

    return :id if id_matches > team_number_matches

    :team_number
  end

  def team_scope
    event.present? ? FrcTeam.at_event(event) : FrcTeam.all
  end
end
