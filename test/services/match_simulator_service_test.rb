# frozen_string_literal: true

require "test_helper"

class MatchSimulatorServiceTest < ActiveSupport::TestCase
  setup do
    @event = events(:championship)
    @service = MatchSimulatorService.new(@event)
  end

  test "constructor RNG and iteration defaults are used and can be overridden" do
    calls = 0
    rng = Object.new
    rng.define_singleton_method(:rand) { calls += 1; 0.5 }
    team = frc_teams(:team_254)
    service = MatchSimulatorService.new(@event, rng: rng, iterations: 3)

    result = service.simulate([ team ], [ team ])
    assert_equal 12, calls
    assert_equal 50.0, result[:red_win_pct]
    assert_equal 50.0, result[:blue_win_pct]

    service.simulate([ team ], [ team ], iterations: 2)
    assert_equal 20, calls
    service.simulate([ team ], [ team ], iterations: 2, rng: Random.new(123))
    assert_equal 20, calls
  end

  test "default simulation uses one thousand iterations with an injectable RNG" do
    calls = 0
    rng = Object.new
    rng.define_singleton_method(:rand) { calls += 1; 0.5 }
    service = MatchSimulatorService.new(@event, rng: rng)

    service.simulate([ frc_teams(:team_254) ], [])

    assert_equal 2000, calls
  end

  test "zero RNG samples produce finite scores" do
    rng = Object.new
    rng.define_singleton_method(:rand) { 0.0 }

    result = @service.simulate([ frc_teams(:team_254) ], [], iterations: 1, rng: rng)

    assert result[:red_avg].finite?
    assert result[:red_avg] >= 0
  end

  test "simulate returns expected hash keys" do
    red_teams = [ frc_teams(:team_254) ]
    blue_teams = [ frc_teams(:team_1678) ]

    result = @service.simulate(red_teams, blue_teams)

    assert result.key?(:red_avg),             "Missing :red_avg"
    assert result.key?(:blue_avg),            "Missing :blue_avg"
    assert result.key?(:red_win_pct),         "Missing :red_win_pct"
    assert result.key?(:blue_win_pct),        "Missing :blue_win_pct"
    assert result.key?(:margin_of_victory),   "Missing :margin_of_victory"
  end

  test "simulate scores are non-negative" do
    red_teams = [ frc_teams(:team_254) ]
    blue_teams = [ frc_teams(:team_1678) ]

    result = @service.simulate(red_teams, blue_teams)

    assert result[:red_avg] >= 0,  "Red avg should be non-negative"
    assert result[:blue_avg] >= 0, "Blue avg should be non-negative"
  end

  test "simulate win percentages sum to approximately 100" do
    red_teams = [ frc_teams(:team_254) ]
    blue_teams = [ frc_teams(:team_1678) ]

    result = @service.simulate(red_teams, blue_teams)

    total_pct = result[:red_win_pct] + result[:blue_win_pct]
    assert_in_delta 100.0, total_pct, 0.1, "Win percentages should sum to ~100"
  end

  test "simulate margin_of_victory matches score difference" do
    red_teams = [ frc_teams(:team_254) ]
    blue_teams = [ frc_teams(:team_1678) ]

    result = @service.simulate(red_teams, blue_teams)

    expected_margin = (result[:red_avg] - result[:blue_avg]).abs.round(2)
    assert_in_delta expected_margin, result[:margin_of_victory], 0.01
  end

  test "simulate with full 3v3 alliances from fixtures" do
    # qm1: red = 254, 4414, 118  vs  blue = 1678
    red_teams = [ frc_teams(:team_254), frc_teams(:team_4414), frc_teams(:team_118) ]
    blue_teams = [ frc_teams(:team_1678) ]

    result = @service.simulate(red_teams, blue_teams)

    # Red has 3 teams (even though 4414 and 118 are unscouted with 0 avg
    # using DEFAULT_STDDEV), blue has 1 team
    assert result[:red_avg].is_a?(Numeric)
    assert result[:blue_avg].is_a?(Numeric)
    assert result[:red_win_pct] >= 0
    assert result[:blue_win_pct] >= 0
  end

  test "simulate with unscouted teams uses default stddev" do
    # team_4414 has no entries => avg=0, stddev defaults to 5.0
    red_teams = [ frc_teams(:team_4414) ]
    blue_teams = [ frc_teams(:team_4414) ]

    result = @service.simulate(red_teams, blue_teams)

    # Both sides are identical, so win pct should be roughly 50/50
    assert_in_delta 50.0, result[:red_win_pct], 10.0
    assert_in_delta 50.0, result[:blue_win_pct], 10.0
  end

  test "simulate is deterministic-ish: stronger team wins more often" do
    # team_254 avg ~58.5 vs team_1678 avg ~39.0
    # Run multiple simulations and check the average trend to reduce flakiness
    red_teams = [ frc_teams(:team_254) ]
    blue_teams = [ frc_teams(:team_1678) ]

    red_win_sum = 0.0
    runs = 5
    runs.times do
      result = @service.simulate(red_teams, blue_teams)
      red_win_sum += result[:red_win_pct]
    end

    avg_red_win_pct = red_win_sum / runs
    assert avg_red_win_pct > 50.0,
           "Team 254 (avg ~58.5) should win more often than Team 1678 (avg ~39.0) on average, got #{avg_red_win_pct}%"
  end
end
