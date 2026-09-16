class QrImportsController < ApplicationController
  include SyncCsrfProtection

  QR_DATA_KEYS = %i[
    auton_fuel_made auton_fuel_missed
    teleop_fuel_made teleop_fuel_missed
    endgame_fuel_made endgame_fuel_missed
    auton_climb endgame_climb defense_rating
  ].freeze
  MAX_QR_NOTES_LENGTH = 2000

  skip_forgery_protection only: :import
  before_action :verify_sync_origin, only: :import

  # GET /qr_imports/scanner
  def scanner
    authorize :qr_import, :scanner?
  end

  # POST /qr_imports/import
  # Accepts a single scouting entry decoded from a QR code.
  # Uses Last-Write-Wins (LWW) conflict resolution when a client_uuid already exists.
  def import
    authorize :qr_import, :import?

    entry_params = params.require(:entry).permit(
      :client_uuid, :match_key, :team_number, :event_key,
      :notes, :status, :updated_at, :scouting_mode, :video_key, :video_type,
      data: [ *QR_DATA_KEYS, { auton_path: [], auton_actions: [] } ]
    )

    # Validate required fields
    unless entry_params[:client_uuid].present? && entry_params[:event_key].present? && entry_params[:team_number].present?
      render json: { status: "error", errors: [ "Missing required fields (client_uuid, event_key, team_number)" ] }, status: :unprocessable_entity
      return
    end

    # Look up the event by TBA key
    event = Event.find_by(tba_key: entry_params[:event_key].to_s.strip.first(32))
    unless event
      render json: { status: "error", errors: [ "Invalid event." ] }, status: :unprocessable_entity
      return
    end

    # Look up the team
    team = FrcTeam.find_by(team_number: entry_params[:team_number].to_i)
    unless team
      render json: { status: "error", errors: [ "Invalid team." ] }, status: :unprocessable_entity
      return
    end

    # Look up the match (optional)
    match = nil
    if entry_params[:match_key].present?
      match = Match.find_by(event: event, tba_key: entry_params[:match_key].to_s.strip.first(32))
    end

    sanitized_data = sanitize_qr_data(entry_params[:data])
    sanitized_notes = entry_params[:notes].to_s.strip.first(MAX_QR_NOTES_LENGTH)

    existing = ScoutingEntry.find_by(client_uuid: entry_params[:client_uuid].to_s.strip.first(64))

    if existing
      # LWW conflict resolution: compare timestamps
      incoming_time = parse_qr_time(entry_params[:updated_at]) || existing.updated_at
      server_time = existing.updated_at

      if incoming_time > server_time
        # Incoming is newer — update the existing record
        if existing.update(
          data: sanitized_data,
          notes: sanitized_notes,
          status: existing.approved? ? :approved : ScoutingEntry.sync_status(entry_params[:status]),
          scouting_mode: entry_params[:scouting_mode] || existing.scouting_mode,
          video_key: entry_params[:video_key].to_s.strip.first(255),
          video_type: entry_params[:video_type].to_s.strip.first(50)
        )
          RefreshSummariesJob.perform_later(existing.event_id)

          render json: {
            status: "updated",
            id: existing.id,
            team_number: existing.frc_team.team_number,
            match_name: existing.match&.display_name || "N/A"
          }
        else
          render json: {
            status: "error",
            errors: existing.errors.full_messages
          }, status: :unprocessable_entity
        end
      else
        # Server copy is same age or newer — skip
        render json: {
          status: "existing",
          id: existing.id,
          team_number: existing.frc_team.team_number,
          match_name: existing.match&.display_name || "N/A"
        }
      end
    else
        # New entry — create it, attributed to the current user (the importer)
        entry = ScoutingEntry.new(
          user: current_user,
          match_id: match&.id,
          frc_team_id: team.id,
          event_id: event.id,
          data: sanitized_data,
          notes: sanitized_notes,
          client_uuid: entry_params[:client_uuid].to_s.strip.first(64),
          status: ScoutingEntry.sync_status(entry_params[:status]),
          scouting_mode: entry_params[:scouting_mode] || :live,
          video_key: entry_params[:video_key].to_s.strip.first(255),
          video_type: entry_params[:video_type].to_s.strip.first(50)
        )

      begin
        if entry.save
          RefreshSummariesJob.perform_later(entry.event_id)

          render json: {
            status: "created",
            id: entry.id,
            team_number: entry.frc_team.team_number,
            match_name: entry.match&.display_name || "N/A"
          }
        else
          render json: {
            status: "error",
            errors: entry.errors.full_messages
          }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotUnique
        render json: {
          status: "error",
          errors: [ "You already have an entry for Team #{entry.frc_team.team_number} in #{entry.match&.display_name || 'this match'}" ]
        }, status: :unprocessable_entity
      end
    end
  rescue StandardError => e
    Rails.logger.error("[QrImportsController] QR import failed: #{e.class}: #{e.message}")
    render json: { status: "error", errors: [ "Import failed. Please try again." ] }, status: :unprocessable_entity
  end

  private

  def parse_qr_time(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def sanitize_qr_data(raw)
    source = raw.is_a?(ActionController::Parameters) ? raw.permit(*QR_DATA_KEYS, auton_path: [], auton_actions: []).to_h : raw.to_h
    result = {}
    QR_DATA_KEYS.each do |key|
      value = source[key.to_s].nil? ? source[key] : source[key.to_s]
      result[key.to_s] = value unless value.nil?
    end
    raw_path = source["auton_path"] || source[:auton_path]
    result["auton_path"] = Array(raw_path).first(50) if raw_path.is_a?(Array)
    raw_actions = source["auton_actions"] || source[:auton_actions]
    result["auton_actions"] = Array(raw_actions).map(&:to_s).map { |a| a.first(50) }.first(100) if raw_actions.is_a?(Array)
    result
  end
end
