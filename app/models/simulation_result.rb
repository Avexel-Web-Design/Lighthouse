# frozen_string_literal: true

class SimulationResult < ApplicationRecord
  belongs_to :user
  belongs_to :event

  validates :red_team_ids, presence: true
  validates :blue_team_ids, presence: true
  validate :alliances_must_be_three_vs_three
  validate :alliance_teams_must_belong_to_event

  def red_teams
    teams_for(team_ref_list(red_team_ids))
  end

  def blue_teams
    teams_for(team_ref_list(blue_team_ids))
  end

  def red_avg
    results&.dig("red_avg").to_f
  end

  def blue_avg
    results&.dig("blue_avg").to_f
  end

  def red_win_pct
    results&.dig("red_win_pct").to_f
  end

  def blue_win_pct
    results&.dig("blue_win_pct").to_f
  end

  def margin_of_victory
    results&.dig("margin_of_victory").to_f
  end

  private

  # Alliance columns store FrcTeam ids (what the simulator UI submits), but
  # older rows used team_numbers. Accepts positive integers and integer
  # strings from either scheme so both keep resolving.
  def team_ref_list(value)
    parsed = value.is_a?(String) ? (JSON.parse(value) rescue []) : value
    Array(parsed).filter_map do |entry|
      case entry
      when Integer then entry if entry.positive?
      when String then entry.to_i if entry.match?(/\A\d+\z/) && entry.to_i.positive?
      end
    end
  end

  def teams_for(refs)
    FrcTeam.where(id: refs).or(FrcTeam.where(team_number: refs))
  end

  def alliances_must_be_three_vs_three
    { red_team_ids: red_team_ids, blue_team_ids: blue_team_ids }.each do |attr, value|
      next if team_ref_list(value).size == 3

      errors.add(attr, "must contain exactly 3 teams")
    end
  end

  def alliance_teams_must_belong_to_event
    return if event.blank?

    at_event_ids = FrcTeam.at_event(event).ids
    at_event_numbers = FrcTeam.at_event(event).pluck(:team_number)

    { red_team_ids: red_team_ids, blue_team_ids: blue_team_ids }.each do |attr, value|
      refs = team_ref_list(value)
      next unless refs.size == 3

      missing = refs.reject { |ref| at_event_ids.include?(ref) || at_event_numbers.include?(ref) }
      errors.add(attr, "must only include teams from the selected event") if missing.any?
    end
  end
end
