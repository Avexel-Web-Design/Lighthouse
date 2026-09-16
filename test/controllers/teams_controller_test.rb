require "test_helper"

class TeamsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin_user)
    @event = events(:championship)
    @team = frc_teams(:team_254)
    sign_in_as(@user)
    select_event(@event)
  end

  # --- Index ---

  test "should get index" do
    TeamEventSummary.refresh!

    get teams_path
    assert_response :success
    assert_includes response.body, "Defence"
  end

  test "scout can get index" do
    sign_out :user
    sign_in_as(users(:scout_user))
    select_event(@event)

    get teams_path
    assert_response :success
  end

  test "index requires event" do
    reset!
    sign_in_as(@user)

    get teams_path
    assert_redirected_to events_path
  end

  # --- Show ---

  test "should get show" do
    TeamEventSummary.refresh!

    get team_path(@team)
    assert_response :success
    assert_includes response.body, "Avg Defence Rating"
    assert_includes response.body, "Defence Profile"
  end

  test "should get show for different team" do
    get team_path(frc_teams(:team_1678))
    assert_response :success
  end

  test "scout can get show" do
    sign_out :user
    sign_in_as(users(:scout_user))
    select_event(@event)

    get team_path(@team)
    assert_response :success
  end

  # --- Pit scouting duplicates ---

  test "show uses latest pit entry and lists disagreements when duplicates differ" do
    PitScoutingEntry.create!(
      user: users(:lead_user),
      event: @event,
      frc_team: @team,
      data: { "drivetrain" => "Tank", "robot_weight" => 120 },
      client_uuid: "pit-dup-test-#{SecureRandom.hex(8)}",
      updated_at: 1.hour.from_now
    )

    get team_path(@team)
    assert_response :success
    assert_includes response.body, "Disagreements"
    assert_includes response.body, "Tank"
    assert_includes response.body, "Swerve"
    assert_includes response.body, "2 reports"
  end

  test "show reports agreement when duplicate pit entries match" do
    PitScoutingEntry.create!(
      user: users(:lead_user),
      event: @event,
      frc_team: @team,
      data: pit_scouting_entries(:pit_254).data.deep_dup,
      client_uuid: "pit-agree-test-#{SecureRandom.hex(8)}",
      updated_at: 1.hour.from_now
    )

    get team_path(@team)
    assert_response :success
    assert_includes response.body, "agree on spec fields"
    assert_not_includes response.body, "Disagreements"
  end

  test "show ignores rejected pit entries" do
    PitScoutingEntry.create!(
      user: users(:lead_user),
      event: @event,
      frc_team: @team,
      data: { "drivetrain" => "Tank" },
      status: :rejected,
      client_uuid: "pit-rejected-test-#{SecureRandom.hex(8)}",
      updated_at: 1.hour.from_now
    )

    get team_path(@team)
    assert_response :success
    assert_not_includes response.body, "Disagreements"
    assert_includes response.body, "Swerve"
  end

  # --- Authentication ---

  test "unauthenticated user is redirected" do
    sign_out :user

    get teams_path
    assert_redirected_to new_user_session_path
  end
end
