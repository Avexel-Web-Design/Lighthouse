class QrImportsController < ApplicationController
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
      data: {}
    )

    # Validate required fields
    unless entry_params[:client_uuid].present? && entry_params[:event_key].present? && entry_params[:team_number].present?
      render json: { status: "error", errors: [ "Missing required fields (client_uuid, event_key, team_number)" ] }, status: :unprocessable_entity
      return
    end

    # Look up the event by TBA key
    event = Event.find_by(tba_key: entry_params[:event_key])
    unless event
      render json: { status: "error", errors: [ "Invalid event: #{entry_params[:event_key]}" ] }, status: :unprocessable_entity
      return
    end

    # Look up the team
    team = FrcTeam.find_by(team_number: entry_params[:team_number])
    unless team
      render json: { status: "error", errors: [ "Invalid team: #{entry_params[:team_number]}" ] }, status: :unprocessable_entity
      return
    end

    # Look up the match (optional)
    match = nil
    if entry_params[:match_key].present?
      match = Match.find_by(event: event, tba_key: entry_params[:match_key])
    end

    existing = ScoutingEntry.find_by(client_uuid: entry_params[:client_uuid])

    if existing
      # LWW conflict resolution: compare timestamps
      incoming_time = Time.parse(entry_params[:updated_at]) rescue existing.updated_at
      server_time = existing.updated_at

      if incoming_time > server_time
        # Incoming is newer — update the existing record
        existing.update!(
          data:   entry_params[:data] || {},
          notes:  entry_params[:notes],
          status: existing.approved? ? :approved : ScoutingEntry.sync_status(entry_params[:status]),
          scouting_mode: entry_params[:scouting_mode] || existing.scouting_mode,
          video_key: entry_params[:video_key],
          video_type: entry_params[:video_type]
        )
        # RefreshSummariesJob is enqueued by the ScoutingEntry after_commit callback.

        render json: {
          status: "updated",
          id: existing.id,
          team_number: existing.frc_team.team_number,
          match_name: existing.match&.display_name || "N/A"
        }
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
          user:        current_user,
          match_id:    match&.id,
          frc_team_id: team.id,
          event_id:    event.id,
          data:        entry_params[:data] || {},
          notes:       entry_params[:notes],
          client_uuid: entry_params[:client_uuid],
          status:      ScoutingEntry.sync_status(entry_params[:status]),
          scouting_mode: entry_params[:scouting_mode] || :live,
          video_key:   entry_params[:video_key],
          video_type:  entry_params[:video_type]
        )

      begin
        if entry.save
          # RefreshSummariesJob is enqueued by the ScoutingEntry after_commit callback.

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
    Rails.logger.error("QR import failed: #{e.message}")
    render json: { status: "error", errors: [ e.message ] }, status: :unprocessable_entity
  end

  private

  # Reuse the sync CSRF protection concern
  include SyncCsrfProtection
end
