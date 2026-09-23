# frozen_string_literal: true

require "test_helper"

class ExportServiceTest < ActiveSupport::TestCase
  setup do
    @event = events(:championship)
    @service = ExportService.new(@event)
  end

  test "to_csv returns a string with the expected headers" do
    csv = @service.to_csv

    assert_kind_of String, csv
    parsed = CSV.parse(csv, headers: true)
    assert_equal ExportService::CSV_HEADERS, parsed.headers
  end

  test "to_csv includes one row per scouted team" do
    parsed = CSV.parse(@service.to_csv, headers: true)

    team_numbers = parsed.map { |row| row["Team #"].to_i }
    assert_includes team_numbers, 254
    assert_includes team_numbers, 1678
  end

  test "to_csv ranks the first row as 1" do
    parsed = CSV.parse(@service.to_csv, headers: true)

    assert_equal "1", parsed.first["Rank"]
  end

  test "to_csv works with an event that has no scouting entries" do
    empty_event = Event.create!(
      name: "Empty Event",
      tba_key: "2026exportempty",
      start_date: "2026-05-01",
      end_date: "2026-05-03",
      year: 2026,
      week: 1
    )

    parsed = CSV.parse(ExportService.new(empty_event).to_csv, headers: true)

    assert_equal ExportService::CSV_HEADERS, parsed.headers
    assert_empty parsed
  end

  test "to_pdf returns PDF bytes" do
    pdf = @service.to_pdf

    assert_kind_of String, pdf
    assert pdf.start_with?("%PDF"), "PDF content should start with %PDF"
    assert pdf.length > 100
  end

  test "to_pdf works with an event that has no scouting entries" do
    empty_event = Event.create!(
      name: "Empty PDF Event",
      tba_key: "2026exportpdfempty",
      start_date: "2026-05-01",
      end_date: "2026-05-03",
      year: 2026,
      week: 1
    )

    pdf = ExportService.new(empty_event).to_pdf

    assert pdf.start_with?("%PDF")
  end

  test "to_csv escapes values containing commas and quotes" do
    team = FrcTeam.create!(
      team_number: 9999,
      nickname: 'Quote", Comma Inc.',
      city: "Testville",
      state_prov: "TS",
      country: "USA",
      rookie_year: 2020
    )
    EventTeam.create!(event: @event, frc_team: team)
    ScoutingEntry.create!(
      user: users(:scout_user),
      match: matches(:qm1),
      frc_team: team,
      event: @event,
      data: {
        "auton_fuel_made" => 2, "auton_fuel_missed" => 1,
        "teleop_fuel_made" => 3, "teleop_fuel_missed" => 1,
        "endgame_fuel_made" => 0, "endgame_fuel_missed" => 0,
        "endgame_climb" => "L2", "auton_climb" => false,
        "defense_rating" => 2
      },
      status: :submitted,
      client_uuid: "csv-escape-uuid-1"
    )

    parsed = CSV.parse(@service.to_csv, headers: true)

    row = parsed.find { |r| r["Team #"] == "9999" }
    assert_not_nil row
    assert_equal 'Quote", Comma Inc.', row["Nickname"]
  end
end
