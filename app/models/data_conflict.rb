class DataConflict < ApplicationRecord
  # Associations
  belongs_to :event
  belongs_to :frc_team
  belongs_to :match
  belongs_to :resolved_by, class_name: "User", optional: true

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
