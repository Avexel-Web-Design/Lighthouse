class DataConflict < ApplicationRecord
  # Associations
  belongs_to :event
  belongs_to :frc_team
  belongs_to :match
  belongs_to :resolved_by, class_name: "User", optional: true

  # Validations (field_name scope mirrors idx_data_conflicts_unique)
  validates :field_name, presence: true,
            uniqueness: { scope: %i[event_id frc_team_id match_id] }

  # NOTE: the `values` jsonb column keeps its name deliberately. Renaming it
  # (e.g. to conflicting_values) would touch AggregationService,
  # DataConflictResolutionService, fixtures, and every historical row, so the
  # rename is deferred — see follow-ups. It shadows no ActiveRecord API today.

  # Scopes
  scope :unresolved, -> { where(resolved: false) }
  scope :resolved, -> { where(resolved: true) }

  def conflicting_entries
    event.scouting_entries
         .where(match: match, frc_team: frc_team)
         .where.not(status: :rejected)
         .includes(:user, :frc_team)
         .order(:created_at)
  end
end
