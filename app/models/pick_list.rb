class PickList < ApplicationRecord
  # Associations
  belongs_to :event
  belongs_to :user

  # Validations
  validates :name, presence: true
  validate :entries_belong_to_event

  before_validation :normalize_entries

  # Membership is memoized per entries assignment so normalize + validation +
  # readers share a single DB resolution instead of re-resolving repeatedly.
  def ordered_team_ids
    @ordered_team_ids ||= compute_ordered_team_ids
  end

  def team_count
    ordered_team_ids.size
  end

  def entries=(value)
    @ordered_team_ids = nil
    @invalid_pick_entries = nil
    super
  end

  private

  def normalize_entries
    resolved, invalid = resolve_entries(Array(entries))
    self.entries = resolved
    @ordered_team_ids = resolved
    @invalid_pick_entries = invalid
  end

  def entries_belong_to_event
    return if event.blank?

    invalid = @invalid_pick_entries
    _, invalid = resolve_entries(Array(entries)) if invalid.nil?
    return if invalid.empty?

    errors.add(:entries, "contain teams that are not part of the selected event")
  end

  # Resolves raw entries to event-team ids once. Returns [ids, invalid_inputs]
  # where invalid_inputs are non-blank inputs that match no team at the event.
  def resolve_entries(raw_entries)
    scalar_mode = scalar_entry_mode(raw_entries)
    resolved = []
    invalid = []

    raw_entries.each do |entry|
      next if blank_pick_entry?(entry)

      team_id = extract_team_id(entry, scalar_mode: scalar_mode)
      if team_id
        resolved << team_id
      else
        invalid << entry
      end
    end

    [resolved.uniq, invalid]
  end

  def blank_pick_entry?(entry)
    case entry
    when NilClass then true
    when String then entry.strip.blank?
    when Array, Hash then entry.empty?
    else false
    end
  end

  def compute_ordered_team_ids
    resolve_entries(Array(entries)).first
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
