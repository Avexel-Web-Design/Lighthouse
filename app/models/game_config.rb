class GameConfig < ApplicationRecord
  # Validations (year mirrors the DB UNIQUE index)
  validates :year, presence: true
  validates :year, uniqueness: true
  validates :game_name, presence: true
  validate :only_one_active_config

  # Scopes
  scope :active, -> { where(active: true) }

  # Returns the current active GameConfig
  def self.current
    active.order(year: :desc).first
  end

  private

  # Guard: at most one config may be active (GameConfig.current picks the
  # newest active one, so a second active row would silently shadow data).
  def only_one_active_config
    return unless active?
    return unless self.class.where(active: true).where.not(id: id).exists?

    errors.add(:active, "only one game config can be active at a time")
  end
end
