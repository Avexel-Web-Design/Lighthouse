class PitScoutingEntriesController < ApplicationController
  include SyncCsrfProtection

  MAX_SYNC_BATCH = 100
  MAX_NOTES_LENGTH = 2000
  PIT_DATA_KEYS = %i[
    robot_width robot_length robot_height robot_weight
    drivetrain drive_motor pivot_motor drivetrain_notes
    intake_width intake_mechanism intake_mechanism_other intake_notes
    hopper_x hopper_y hopper_z
    hopper_extended_x hopper_extended_y hopper_extended_z hopper_notes
    indexer indexer_other indexer_notes
    shooter_hood shooter_motor shooter_notes
    climber_type climber_notes
    auton_paths_json auton_notes
    strengths weaknesses
  ].freeze

  before_action :require_event!, except: :sync
  skip_forgery_protection only: :sync
  before_action :verify_sync_origin, only: :sync
  before_action :set_pit_scouting_entry, only: %i[show edit update destroy]

  def index
    @pit_scouting_entries = policy_scope(PitScoutingEntry)
                              .where(event: current_event)
                              .includes(:user, :frc_team)
                              .order(updated_at: :desc)

    @teams = FrcTeam.at_event(current_event).order(:team_number)
    @scouted_team_ids = @pit_scouting_entries.pluck(:frc_team_id).uniq
  end

  def show
    authorize @pit_scouting_entry
  end

  def new
    @pit_scouting_entry = PitScoutingEntry.new(event: current_event)
    authorize @pit_scouting_entry
    @teams = FrcTeam.at_event(current_event).order(:team_number)
  end

  def create
    @pit_scouting_entry = current_user.pit_scouting_entries.build(pit_scouting_entry_params)
    @pit_scouting_entry.event = current_event
    authorize @pit_scouting_entry

    if @pit_scouting_entry.client_uuid.present?
      existing = PitScoutingEntry.find_by(client_uuid: @pit_scouting_entry.client_uuid)
      if existing
        redirect_to existing, notice: "Entry already synced."
        return
      end
    end

    if @pit_scouting_entry.save
      redirect_to @pit_scouting_entry, notice: "Pit scouting entry created."
    else
      @teams = FrcTeam.at_event(current_event).order(:team_number)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @pit_scouting_entry
    @teams = FrcTeam.at_event(current_event).order(:team_number)
  end

  def update
    authorize @pit_scouting_entry

    if @pit_scouting_entry.update(pit_scouting_entry_params)
      redirect_to @pit_scouting_entry, notice: "Pit scouting entry updated."
    else
      @teams = FrcTeam.at_event(current_event).order(:team_number)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @pit_scouting_entry
    @pit_scouting_entry.destroy
    if @pit_scouting_entry.destroyed?
      redirect_to pit_scouting_entries_path, notice: "Pit scouting entry deleted.", status: :see_other
    else
      redirect_to @pit_scouting_entry, alert: "Could not delete pit scouting entry."
    end
  end

  # POST /pit_scouting_entries/sync — offline sync endpoint
  def sync
    authorize :pit_scouting_entry, :sync?

    entries_params = params.require(:entries)
    unless entries_params.is_a?(Array) && entries_params.size <= MAX_SYNC_BATCH
      render json: { error: "Too many entries (max #{MAX_SYNC_BATCH})." }, status: :unprocessable_entity
      return
    end

    results = []
    created_event_ids = []

    entries_params.each do |entry_data|
      results << sync_one_entry(entry_data, created_event_ids)
    end

    # Refresh summaries for the events that actually received new entries
    created_event_ids.uniq.each { |eid| RefreshSummariesJob.perform_later(eid) }

    render json: { results: results }
  end

  private

  def set_pit_scouting_entry
    @pit_scouting_entry = PitScoutingEntry.find(params[:id])
  end

  def pit_scouting_entry_params
    permitted = params.require(:pit_scouting_entry).permit(
      :frc_team_id, :notes, :client_uuid, :status,
      data: [
        :robot_width, :robot_length, :robot_height, :robot_weight,
        :drivetrain, :drive_motor, :pivot_motor, :drivetrain_notes,
        :intake_width, :intake_mechanism, :intake_mechanism_other, :intake_notes,
        :hopper_x, :hopper_y, :hopper_z,
        :hopper_extended_x, :hopper_extended_y, :hopper_extended_z, :hopper_notes,
        :indexer, :indexer_other, :indexer_notes,
        :shooter_hood, :shooter_motor, :shooter_notes,
        :climber_type, :climber_notes,
        :auton_paths_json, :auton_notes,
        :strengths, :weaknesses,
        intake_types: [], shooter_types: [], climber_levels: []
      ],
      photos: []
    )

    # Parse auton_paths from its JSON hidden field into a real array
    if permitted[:data].is_a?(ActionController::Parameters) && permitted[:data][:auton_paths_json].present?
      begin
        permitted[:data][:auton_paths] = JSON.parse(permitted[:data][:auton_paths_json].to_s)
      rescue JSON::ParserError
        permitted[:data][:auton_paths] = []
      end
      permitted[:data].delete(:auton_paths_json)
    end

    permitted[:notes] = permitted[:notes].to_s.strip.first(MAX_NOTES_LENGTH) if permitted[:notes].present?

    permitted
  end

  def sync_one_entry(entry_data, created_event_ids)
    client_uuid = entry_data[:client_uuid].to_s.strip.first(64)
    entry = client_uuid.present? ? PitScoutingEntry.find_by(client_uuid: client_uuid) : nil

    if entry
      { client_uuid: client_uuid, status: "existing", id: entry.id }
    else
      permitted = entry_data.permit(:frc_team_id, :event_id, :notes, :client_uuid, :status).merge(user_id: current_user.id)
      permitted[:data] = sanitize_pit_data(entry_data[:data])
      permitted[:notes] = permitted[:notes].to_s.strip.first(MAX_NOTES_LENGTH) if permitted[:notes].present?

      sync_event = sync_event_for(permitted[:event_id])
      unless sync_event
        return { client_uuid: client_uuid, status: "error", errors: [ "Invalid event" ] }
      end

      entry = PitScoutingEntry.from_offline_data(permitted)
      if entry.save
        created_event_ids << sync_event.id
        { client_uuid: client_uuid, status: "created", id: entry.id }
      else
        { client_uuid: client_uuid, status: "error", errors: entry.errors.full_messages }
      end
    end
  rescue StandardError => e
    Rails.logger.warn("[PitScoutingEntriesController] Sync row failed: #{e.class}: #{e.message}")
    { client_uuid: entry_data[:client_uuid].to_s, status: "error", errors: [ "Could not save entry" ] }
  end

  def sync_event_for(event_id)
    sync_event = Event.find_by(id: event_id.to_i)
    return nil if sync_event.nil?
    return nil if current_event.present? && sync_event.id != current_event.id

    sync_event
  end

  def sanitize_pit_data(raw)
    source = raw.is_a?(ActionController::Parameters) ? raw.permit(*PIT_DATA_KEYS, intake_types: [], shooter_types: [], climber_levels: [], auton_paths: []).to_h : raw.to_h
    result = {}
    PIT_DATA_KEYS.each do |key|
      value = source[key.to_s].nil? ? source[key] : source[key.to_s]
      result[key.to_s] = value unless value.nil?
    end
    %w[intake_types shooter_types climber_levels].each do |key|
      values = source[key] || source[key.to_s]
      result[key] = Array(values).map(&:to_s).map { |v| v.first(100) }.first(20) if values.present?
    end
    paths = source["auton_paths"] || source[:auton_paths]
    result["auton_paths"] = Array(paths).first(50) if paths.is_a?(Array)
    result
  end
end
