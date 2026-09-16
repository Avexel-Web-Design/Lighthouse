class Event < ApplicationRecord
  QUALIFICATION_MATCH_COUNT = 80

  # Associations
  has_many :matches, dependent: :destroy
  has_many :event_teams, dependent: :destroy
  has_many :frc_teams, through: :event_teams
  has_many :scouting_entries, dependent: :destroy
  has_many :scouting_assignments, dependent: :destroy
  has_many :pit_scouting_entries, dependent: :destroy
  has_many :predictions, dependent: :destroy
  has_many :simulation_results, dependent: :destroy
  has_many :data_conflicts, dependent: :destroy
  has_many :pick_lists, dependent: :destroy
  has_many :statbotics_caches, class_name: "StatboticsCache", dependent: :destroy

  # TBA event_type integers (https://www.thebluealliance.com/api/v3#event).
  # The event form only exposes a subset, but the enum covers every value TBA
  # sends so sync never raises on assignment.
  enum :event_type, {
    regional: 0,
    district: 1,
    district_championship: 2,
    championship_division: 3,
    championship_finals: 4,
    district_championship_division: 5,
    festival_of_champions: 6,
    offseason: 99,
    preseason: 100
  }, validate: false

  # Validations
  validates :name, presence: true
  validates :year, presence: true, numericality: { only_integer: true, allow_nil: true }
  validates :tba_key, uniqueness: true, allow_nil: true

  # Scopes
  scope :current_year, -> { where(year: Date.current.year) }
  scope :active, -> {
    today = Date.current
    where("start_date <= ? AND end_date >= ?", today, today)
  }

  # Coerce form/TBA input and unknown future TBA event_type integers to nil
  # instead of raising ArgumentError on assignment, so Event sync stays resilient.
  def event_type=(value)
    value = value.to_i if value.is_a?(String) && value.match?(/\A\d+\z/)
    mapped = self.class.event_types
    if value.is_a?(Integer) && !mapped.value?(value)
      super(nil)
    else
      super
    end
  rescue ArgumentError
    super(nil)
  end

  def ensure_qualification_matches!
    with_lock do
      existing_numbers = matches.where(comp_level: "qm", match_number: 1..QUALIFICATION_MATCH_COUNT).pluck(:match_number)
      missing_numbers = (1..QUALIFICATION_MATCH_COUNT).to_a - existing_numbers

      missing_numbers.each do |match_number|
        matches.find_or_create_by!(comp_level: "qm", set_number: 1, match_number: match_number)
      end
    end
  end
end
