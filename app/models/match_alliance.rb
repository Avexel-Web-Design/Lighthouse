class MatchAlliance < ApplicationRecord
  # Associations
  belongs_to :match
  belongs_to :frc_team

  # Validations (the two uniqueness validations mirror the DB indexes:
  # (match, frc_team) and (match, alliance_color, station))
  validates :match_id, uniqueness: { scope: :frc_team_id }
  validates :alliance_color, presence: true, inclusion: { in: %w[red blue] }
  validates :station, presence: true, inclusion: { in: 1..3 }
  validates :station, uniqueness: { scope: %i[match_id alliance_color] }
end
