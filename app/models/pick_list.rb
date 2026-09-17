class PickList < ApplicationRecord
  # Associations
  belongs_to :event
  belongs_to :user

  # Validations
  validates :name, presence: true
  validate :entries_belong_to_event

  before_validation :normalize_entries

  def ordered_team_ids
    raw = Array(entries)
    return [] if raw.empty?

    ids_set, number_to_id = team_lookup_maps
    scalar_mode = scalar_entry_mode(raw, ids_set, number_to_id)
    raw.filter_map { |entry| extract_team_id(entry, scalar_mode: scalar_mode, ids_set: ids_set, number_to_id: number_to_id) }.uniq
  end

  def team_count
    ordered_team_ids.size
  end

  private

  def normalize_entries
    resolved = resolve_entry_inputs
    self.entries = resolved.compact.uniq unless resolved.include?(nil)
  end

  def entries_belong_to_event
    return if event.blank? || !resolve_entry_inputs.include?(nil)

    errors.add(:entries, "contain teams that are not part of the selected event")
  end

  def resolve_entry_inputs
    raw = Array(entries).reject(&:blank?)
    ids_set, number_to_id = team_lookup_maps
    scalar_mode = scalar_entry_mode(raw, ids_set, number_to_id)
    raw.map { |entry| extract_team_id(entry, scalar_mode: scalar_mode, ids_set: ids_set, number_to_id: number_to_id) }
  end

  # Single batched lookup for all event teams: Set of ids + team_number => id.
  # Replaces per-entry find_by calls and per-validation count queries.
  def team_lookup_maps
    rows = team_scope.pluck(:id, :team_number)
    [ rows.map(&:first).to_set, rows.to_h { |id, number| [ number, id ] } ]
  end

  def extract_team_id(entry, scalar_mode: nil, ids_set: nil, number_to_id: nil)
    ids_set, number_to_id = team_lookup_maps if ids_set.nil? || number_to_id.nil?

    case entry
    when Integer
      team_id_from_scalar(entry, scalar_mode, ids_set, number_to_id)
    when String
      team_id_from_scalar(entry.to_i, scalar_mode, ids_set, number_to_id) if entry.match?(/\A\d+\z/)
    when Hash
      team_id_from_id(entry["id"] || entry[:id] || entry["team_id"] || entry[:team_id] || entry["frc_team_id"] || entry[:frc_team_id], ids_set) ||
        team_id_from_number(entry["team_number"] || entry[:team_number], number_to_id)
    end
  end

  def team_id_from_number(team_number, number_to_id = nil)
    return if team_number.blank?

    number_to_id ||= team_lookup_maps.last
    number_to_id[team_number.to_i]
  end

  def team_id_from_scalar(value, scalar_mode, ids_set = nil, number_to_id = nil)
    candidate = value.to_i
    return if candidate <= 0

    ids_set, number_to_id = team_lookup_maps if ids_set.nil? || number_to_id.nil?

    return team_id_from_number(candidate, number_to_id) if scalar_mode == :team_number

    team_id_from_id(candidate, ids_set) || team_id_from_number(candidate, number_to_id)
  end

  def team_id_from_id(value, ids_set = nil)
    return if value.blank?

    candidate = value.to_i
    return if candidate <= 0

    ids_set ||= team_lookup_maps.first
    ids_set.include?(candidate) ? candidate : nil
  end

  def scalar_entry_mode(raw_entries, ids_set = nil, number_to_id = nil)
    scalar_values = raw_entries.filter_map do |entry|
      case entry
      when Integer
        entry if entry.positive?
      when String
        entry.to_i if entry.match?(/\A\d+\z/)
      end
    end.uniq

    return :team_number if scalar_values.empty?

    ids_set, number_to_id = team_lookup_maps if ids_set.nil? || number_to_id.nil?

    id_matches = scalar_values.count { |v| ids_set.include?(v) }
    team_number_matches = scalar_values.count { |v| number_to_id.key?(v) }

    return :id if id_matches > team_number_matches

    :team_number
  end

  def team_scope
    event.present? ? FrcTeam.at_event(event) : FrcTeam.all
  end
end
