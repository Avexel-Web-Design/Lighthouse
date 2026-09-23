require "test_helper"

class PredictionServiceWeightsTest < ActiveSupport::TestCase
  setup do
    @event = events(:championship)
    @service = PredictionService.new(@event)
  end

  test "compute_weights counts approved entries as scouting data" do
    team = frc_teams(:team_254)

    ScoutingEntry.where(event: @event, frc_team: team).delete_all

    6.times do |i|
      ScoutingEntry.create!(
        event: @event,
        frc_team: team,
        user: users(:admin_user),
        match: @event.matches.create!(comp_level: "qm", match_number: 101 + i, set_number: 1),
        scouting_mode: :replay,
        status: :approved,
        client_uuid: "prediction-approved-#{i}",
        data: {
          "auton_fuel_made" => 1,
          "auton_fuel_missed" => 0,
          "teleop_fuel_made" => 1,
          "teleop_fuel_missed" => 0,
          "endgame_fuel_made" => 0,
          "endgame_fuel_missed" => 0,
          "auton_climb" => false,
          "endgame_climb" => "None"
        }
      )
    end

    statbotics_data = { red_score: 100.0, blue_score: 100.0, red_win_pct: 50.0, blue_win_pct: 50.0 }
    scouting_weight, statbotics_weight = @service.send(:compute_weights, [ team ], statbotics_data)

    assert_in_delta 0.5, scouting_weight, 0.001
    assert_in_delta 0.5, statbotics_weight, 0.001
  end
end
