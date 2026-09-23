class ScoutingEntry < ApplicationRecord
  include Scoring

  COUNTED_STATUSES = %w[submitted approved].freeze
  REVIEWABLE_SYNC_STATUSES = %w[submitted flagged rejected].freeze

  # Associations
  belongs_to :user
  belongs_to :match, optional: true
  belongs_to :frc_team
  belongs_to :event

  # Enums
  enum :status, { submitted: 0, flagged: 1, rejected: 2, approved: 3 }
  enum :scouting_mode, { live: 0, replay: 1 }

  # Scopes
  scope :counted, -> { where(status: counted_status_values) }

  # Validations
  # client_uuid is globally unique when present; NULLs dedupe via LWW in the
  # sync/import endpoints (Postgres treats NULLs as distinct, matching
  # allow_nil here). Blank strings normalize to nil so two "absent" uuids
  # never collide on the unique index.
  normalizes :client_uuid, with: ->(uuid) { uuid.presence }
  validates :client_uuid, uniqueness: true, allow_nil: true
  # match_id is nullable (match-less entries); NULL match_ids skip this check
  # (as does the DB unique index, which treats NULLs as distinct), while
  # LWW on client_uuid remains the dedup path for those rows.
  validates :match_id, uniqueness: { scope: %i[event_id frc_team_id user_id scouting_mode] }, allow_nil: true

  # Callbacks
  after_create_commit :broadcast_prepend_entry
  after_update_commit :broadcast_replace_entry
  after_destroy_commit :broadcast_remove_entry
  # Safety net so every mutation path (web UI, offline sync, QR import,
  # conflict resolution, console) refreshes aggregates. Single-record
  # controller actions rely on this callback; bulk sync endpoints enqueue one
  # job per event on top, which is idempotent, so overlap is harmless.
  after_commit :enqueue_summary_refresh, on: %i[create update destroy]

  # --- Computed methods reading from JSONB data column ---

  # Total fuel scored across auton and teleop.
  def total_fuel_made
    (dig_int("auton_fuel_made") || 0) + (dig_int("teleop_fuel_made") || 0) + (dig_int("endgame_fuel_made") || 0)
  end

  # Total fuel missed across auton and teleop.
  def total_fuel_missed
    (dig_int("auton_fuel_missed") || 0) + (dig_int("teleop_fuel_missed") || 0) + (dig_int("endgame_fuel_missed") || 0)
  end

  # Fuel accuracy as a percentage (0-100). Returns 0.0 when no attempts.
  def fuel_accuracy
    total = total_fuel_made + total_fuel_missed
    return 0.0 if total.zero?

    (total_fuel_made.to_f / total * 100).round(1)
  end

  # Total points for this entry
  def total_points
    points = total_fuel_made * FUEL_POINT_VALUE

    points += AUTON_CLIMB_POINTS if ActiveModel::Type::Boolean.new.cast(data&.dig("auton_climb"))

    climb_level = data&.dig("endgame_climb").to_s
    points += CLIMB_POINTS.fetch(climb_level, 0)

    points
  end

  # Auton points for this entry (auton fuel + auton climb bonus)
  def auton_points
    pts = (dig_int("auton_fuel_made") || 0) * FUEL_POINT_VALUE
    pts += AUTON_CLIMB_POINTS if ActiveModel::Type::Boolean.new.cast(data&.dig("auton_climb"))
    pts
  end

  # Climb points for this entry (auton climb + endgame climb)
  def climb_points
    pts = 0
    pts += AUTON_CLIMB_POINTS if ActiveModel::Type::Boolean.new.cast(data&.dig("auton_climb"))
    pts += CLIMB_POINTS.fetch(data&.dig("endgame_climb").to_s, 0)
    pts
  end

  # Defence rating (1-5, 0 means not rated)
  def defense_rating
    dig_int("defense_rating") || 0
  end

  # Returns the array of autonomous actions from the JSONB data
  def auton_actions
    data&.dig("auton_actions") || []
  end

  # Build a ScoutingEntry from offline/sync data
  def self.from_offline_data(params)
    new(
      user_id: params[:user_id],
      match_id: params[:match_id],
      frc_team_id: params[:frc_team_id],
      event_id: params[:event_id],
      data: params[:data] || {},
      notes: params[:notes],
      photo_url: params[:photo_url],
      client_uuid: params[:client_uuid],
      status: sync_status(params[:status]),
      scouting_mode: params[:scouting_mode] || :live,
      video_key: params[:video_key],
      video_type: params[:video_type]
    )
  end

  def self.counted_status_values
    statuses.values_at(*COUNTED_STATUSES)
  end

  def self.sync_status(value)
    normalized = value.to_s.presence || "submitted"
    return :submitted unless REVIEWABLE_SYNC_STATUSES.include?(normalized)

    normalized
  end

  def mode_label
    replay? ? "Replay" : "Live"
  end

  def counted?
    submitted? || approved?
  end

  def status_badge_class
    case status
    when "submitted"
      "badge-orange"
    when "flagged"
      "badge-amber"
    when "approved"
      "badge-emerald"
    when "rejected"
      "badge-red"
    else
      "badge-gray"
    end
  end

  def status_label
    return "Inaccurate" if flagged?
    return "Admin Approved" if approved?

    status&.capitalize || "Draft"
  end

  private

  def broadcast_prepend_entry
    broadcast_prepend_to(
      "scouting_entries_event_#{event_id}",
      target: "scouting_entries",
      partial: "scouting_entries/scouting_entry",
      locals: { scouting_entry: self }
    )
  end

  def broadcast_replace_entry
    broadcast_replace_to(
      "scouting_entries_event_#{event_id}",
      target: "scouting_entry_#{id}",
      partial: "scouting_entries/scouting_entry",
      locals: { scouting_entry: self }
    )
  end

  def broadcast_remove_entry
    broadcast_remove_to(
      "scouting_entries_event_#{event_id}",
      target: "scouting_entry_#{id}"
    )
  end

  def enqueue_summary_refresh
    RefreshSummariesJob.perform_later(event_id)
  end

  # Safely dig an integer value from the JSONB data hash. Returns nil for
  # missing or non-integer values instead of coercing with to_i, which hides
  # bad data ("abc".to_i == 0). Callers default nil to 0 where a number is
  # required for arithmetic.
  def dig_int(key)
    value = data&.dig(key)
    return value if value.is_a?(Integer)
    return value.to_i if value.is_a?(String) && value.match?(/\A-?\d+\z/)

    nil
  end
end
