# frozen_string_literal: true

class SimulationResult < ApplicationRecord
  belongs_to :user
  belongs_to :event

  validates :red_team_ids, presence: true
  validates :blue_team_ids, presence: true
  validate :valid_alliance_references
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

  def team_ref_list(value)
    parsed = value.is_a?(String) ? JSON.parse(value) : value
    return [] unless parsed.is_a?(Array)

    parsed.map do |entry|
      case entry
      when Integer then entry if entry.positive?
      when String then entry.to_i if entry.match?(/\A\d+\z/) && entry.to_i.positive?
      end
    end
  rescue JSON::ParserError
    []
  end

  def resolved_team_ids(refs)
    ids = FrcTeam.where(id: refs.compact).pluck(:id)
    numbers = FrcTeam.where(team_number: refs.compact - ids).pluck(:team_number, :id).to_h
    refs.map { |ref| ids.include?(ref) ? ref : numbers[ref] }
  end

  def teams_for(refs)
    FrcTeam.where(id: resolved_team_ids(refs).compact)
  end

  def valid_alliance_references
    { red_team_ids: red_team_ids, blue_team_ids: blue_team_ids }.each do |attr, value|
      refs = team_ref_list(value)
      next if refs.present? && refs.none?(&:nil?)

      errors.add(attr, "must contain valid team references")
    end
  end

  def alliance_teams_must_belong_to_event
    return if event.blank?

    at_event_ids = FrcTeam.at_event(event).ids

    { red_team_ids: red_team_ids, blue_team_ids: blue_team_ids }.each do |attr, value|
      ids = resolved_team_ids(team_ref_list(value))
      next if (ids - at_event_ids).empty?

      errors.add(attr, "must only include teams from the selected event")
    end
  end
end
