# frozen_string_literal: true

class ExcelExportService
  # Shared with ExportService to avoid header drift between CSV/PDF/XLSX.
  SUMMARY_HEADERS = ExportService::CSV_HEADERS

  def initialize(event)
    @event = event
    @aggregation = AggregationService.new(event)
  end

  def generate
    package = Axlsx::Package.new
    workbook = package.workbook

    # Summary sheet
    add_summary_sheet(workbook)

    # Raw data sheet
    add_raw_data_sheet(workbook)

    # Pit scouting sheet
    add_pit_scouting_sheet(workbook)

    package.to_stream.read
  end

  private

  def add_summary_sheet(workbook)
    aggregations = @aggregation.aggregate_all_teams

    workbook.add_worksheet(name: "Team Summary") do |sheet|
      header_style = sheet.styles.add_style(b: true, bg_color: "333333", fg_color: "FFFFFF", sz: 10)
      sheet.styles.add_style(num_fmt: 1)

      sheet.add_row SUMMARY_HEADERS, style: header_style

      aggregations.each_with_index do |agg, idx|
        team = agg[:frc_team]
        sheet.add_row [
          idx + 1,
          team.team_number,
          team.nickname,
          agg[:avg_fuel_made],
          agg[:avg_fuel_missed],
          agg[:fuel_accuracy_pct],
          agg[:avg_climb_points],
          agg[:avg_total_points],
          agg[:stddev_total_points],
          agg[:matches_scouted],
          agg[:confidence]
        ]
      end
    end
  end

  def add_raw_data_sheet(workbook)
    entries = ScoutingEntry.where(event: @event).includes(:user, :frc_team, :match).order(:created_at)

    workbook.add_worksheet(name: "Raw Scouting Data") do |sheet|
      header_style = sheet.styles.add_style(b: true, bg_color: "333333", fg_color: "FFFFFF", sz: 10)

        sheet.add_row [
          "ID", "Match", "Team #", "Scout", "Status",
          "Auton Made", "Auton Missed", "Auton Climb",
          "Teleop Made", "Teleop Missed",
          "Endgame Climb", "Defence Rating",
          "Total Points", "Fuel Accuracy %", "Notes", "Created At"
        ], style: header_style

      entries.find_each do |entry|
        sheet.add_row [
          entry.id,
          entry.match&.display_name,
          entry.frc_team.team_number,
          entry.user.full_name,
          entry.status,
          entry.data&.dig("auton_fuel_made").to_i,
          entry.data&.dig("auton_fuel_missed").to_i,
          entry.data&.dig("auton_climb"),
          entry.data&.dig("teleop_fuel_made").to_i + entry.data&.dig("endgame_fuel_made").to_i,
          entry.data&.dig("teleop_fuel_missed").to_i + entry.data&.dig("endgame_fuel_missed").to_i,
          entry.data&.dig("endgame_climb"),
          entry.data&.dig("defense_rating").to_i,
          entry.total_points,
          entry.fuel_accuracy,
          entry.notes,
          entry.created_at.strftime("%Y-%m-%d %H:%M")
        ]
      end
    end
  end

  def add_pit_scouting_sheet(workbook)
    entries = PitScoutingEntry.where(event: @event).includes(:user, :frc_team).order(:frc_team_id)

    workbook.add_worksheet(name: "Pit Scouting") do |sheet|
      header_style = sheet.styles.add_style(b: true, bg_color: "333333", fg_color: "FFFFFF", sz: 10)

      sheet.add_row [
        "Team #", "Nickname", "Scout", "Drivetrain",
        "Width", "Length", "Height", "Weight",
        "Strengths", "Weaknesses", "Notes", "Scouted At"
      ], style: header_style

      entries.find_each do |entry|
        sheet.add_row [
          entry.frc_team.team_number,
          entry.frc_team.nickname,
          entry.user.full_name,
          entry.drivetrain,
          entry.robot_width,
          entry.robot_length,
          entry.robot_height,
          entry.robot_weight,
          entry.strengths,
          entry.weaknesses,
          entry.notes,
          entry.created_at.strftime("%Y-%m-%d %H:%M")
        ]
      end
    end
  end
end
