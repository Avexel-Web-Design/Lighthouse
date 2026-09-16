class GameConfig < ApplicationRecord
  # Validations (year mirrors the DB UNIQUE index)
  validates :year, presence: true
  validates :year, uniqueness: true
  validates :game_name, presence: true

  # Scopes
  scope :active, -> { where(active: true) }

  # Returns the current active GameConfig
  def self.current
    active.order(year: :desc).first
  end
end
