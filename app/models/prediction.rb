# frozen_string_literal: true

class Prediction < ApplicationRecord
  belongs_to :match
  belongs_to :event

  validates :source, presence: true,
            inclusion: { in: %w[scouting statbotics blended] }
  validates :match_id, uniqueness: { scope: :source }

  scope :for_event, ->(event) { where(event: event) }
  scope :blended, -> { where(source: "blended") }

  def winner
    return "red" if red_win_probability.to_f > 50
    return "blue" if blue_win_probability.to_f > 50
    "tie"
  end

  def correct?
    return nil unless actual_red_score && actual_blue_score

    predicted_winner = red_score.to_f >= blue_score.to_f ? "red" : "blue"
    actual_winner = actual_red_score >= actual_blue_score ? "red" : "blue"
    predicted_winner == actual_winner
  end

  def margin_of_victory
    (red_score.to_f - blue_score.to_f).abs.round(1)
  end
end
