# frozen_string_literal: true

class ExportService
  CSV_HEADERS = [
    "Rank", "Team #", "Nickname", "Avg Fuel Made", "Avg Fuel Missed",
    "Fuel Accuracy %", "Avg Climb Pts", "Avg Total Pts", "Std Dev",
    "Matches Scouted", "Confidence"
  ].freeze

  def initialize(event)
    @event = event
    @aggregation_service = AggregationService.new(event)
  end

  # Single fetch shared by to_csv / to_pdf on the same instance
  # (was: one aggregate_all_teams query per format).
  def aggregations
    @aggregations ||= @aggregation_service.aggregate_all_teams
  end

  # Exports team summary data as a CSV string.
  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << CSV_HEADERS

      aggregations.each_with_index do |agg, index|
        csv << summary_row(agg, index)
      end
    end
  end

  # Generates a PDF report with team rankings using Prawn.
  def to_pdf
    rows = aggregations

    Prawn::Document.new(page_size: "LETTER", page_layout: :landscape) do |pdf|
      render_header(pdf)
      render_table(pdf, rows)
      render_footer(pdf)
    end.render
  end

  private

  def summary_row(agg, index)
    team = agg[:frc_team]
    [
      index + 1,
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

  def render_header(pdf)
    pdf.text "Lighthouse - Team Rankings", size: 20, style: :bold
    pdf.text "#{@event.name} (#{@event.tba_key})", size: 14
    pdf.text "Generated: #{Time.current.strftime('%B %d, %Y at %I:%M %p')}", size: 10
    pdf.move_down 15
  end

  def render_table(pdf, aggregations)
    table_data = [ CSV_HEADERS ]

    aggregations.each_with_index do |agg, index|
      team = agg[:frc_team]
      table_data << [
        index + 1,
        team.team_number,
        team.nickname.to_s.truncate(20),
        agg[:avg_fuel_made],
        agg[:avg_fuel_missed],
        "#{agg[:fuel_accuracy_pct]}%",
        agg[:avg_climb_points],
        agg[:avg_total_points],
        agg[:stddev_total_points],
        agg[:matches_scouted],
        agg[:confidence]
      ]
    end

    return if table_data.size < 2

    pdf.table(table_data, header: true, width: pdf.bounds.width) do |t|
      t.row(0).font_style = :bold
      t.row(0).background_color = "333333"
      t.row(0).text_color = "FFFFFF"
      t.row(0).size = 9
      t.cells.size = 8
      t.cells.padding = [ 4, 6 ]
      t.cells.borders = [ :bottom ]
      t.cells.border_width = 0.5
      t.cells.border_color = "CCCCCC"

      # Alternate row colors for readability
      t.rows(1..-1).each_with_index do |row, i|
        row.background_color = i.even? ? "F5F5F5" : "FFFFFF"
      end

      # Right-align numeric columns (all except rank, nickname, confidence)
      numeric_columns = [ 0, 1, 3, 4, 5, 6, 7, 8, 9 ]
      numeric_columns.each do |col|
        t.column(col).align = :right
      end
    end
  end

  def render_footer(pdf)
    pdf.number_pages "Page <page> of <total>",
                     at: [ pdf.bounds.right - 100, 0 ],
                     size: 8
  end
end
