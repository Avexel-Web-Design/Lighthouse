class ScoutingEntriesController < ApplicationController
  include SyncCsrfProtection

  helper_method :replay_embed_url_for, :replay_watch_url_for

  before_action :require_event!, except: :sync
  skip_forgery_protection only: :sync
  before_action :verify_sync_origin, only: :sync
  before_action :set_scouting_entry, only: %i[show edit update destroy approve]
  before_action :set_replay_form, only: :replay

  def index
    @scouting_entries = policy_scope(ScoutingEntry)
                          .where(event: current_event)
                          .includes(:user, :frc_team, :match)
                          .order(created_at: :desc)
  end

  def show
    authorize @scouting_entry
    compute_entry_accuracy
    @next_match = NextScoutMatchService.new(current_event).next_match(after_match: @scouting_entry.match)
  end

  def new
    @scouting_entry = ScoutingEntry.new(event: current_event, scouting_mode: :live)
    @scouting_entry.match_id = params[:match_id] if params[:match_id].present?
    @scouting_entry.frc_team_id = params[:frc_team_id] if params[:frc_team_id].present?
    authorize @scouting_entry

    setup_live_form
  end

  def replay
    authorize :scouting_entry, :replay?
  end

  def create
    @scouting_entry = current_user.scouting_entries.build(scouting_entry_params)
    @scouting_entry.event = current_event
    authorize @scouting_entry

    # Handle offline sync: if a duplicate client_uuid exists, apply LWW
    if @scouting_entry.client_uuid.present?
      existing = ScoutingEntry.find_by(client_uuid: @scouting_entry.client_uuid)
      if existing
        redirect_to existing, notice: "Entry already exists."
        return
      end
    end

    if @scouting_entry.save
      @scouting_entry.broadcast_prepend_to(
        "scouting_entries_event_#{current_event.id}",
        target: "scouting_entries",
        partial: "scouting_entries/scouting_entry",
        locals: { scouting_entry: @scouting_entry }
      )
      RefreshSummariesJob.perform_later(current_event.id)
      redirect_to @scouting_entry, notice: success_notice_for(@scouting_entry)
    else
      if @scouting_entry.replay?
        set_replay_form
        render :replay, status: :unprocessable_entity
      else
        setup_live_form
        render :new, status: :unprocessable_entity
      end
    end
  end

  def edit
    authorize @scouting_entry

    if replay_entry_locked?
      set_replay_form
      render :replay
    else
      setup_live_form(include_match: @scouting_entry.match)
    end
  end

  def update
    authorize @scouting_entry

    if @scouting_entry.update(scouting_entry_params)
      RefreshSummariesJob.perform_later(current_event.id)
      redirect_to @scouting_entry, notice: "Scouting entry was successfully updated."
    else
      if replay_entry_locked?
        set_replay_form
        render :replay, status: :unprocessable_entity
      else
        setup_live_form(include_match: @scouting_entry.match)
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def destroy
    authorize @scouting_entry
    event_id = @scouting_entry.event_id
    @scouting_entry.destroy!
    RefreshSummariesJob.perform_later(event_id)
    redirect_to scouting_entries_path, notice: "Scouting entry was successfully deleted.", status: :see_other
  end

  def approve
    authorize @scouting_entry, :approve?

    unless @scouting_entry.flagged?
      redirect_to @scouting_entry, alert: "Only flagged entries can be admin approved."
      return
    end

    @scouting_entry.update!(status: :approved)
    RefreshSummariesJob.perform_now(@scouting_entry.event_id)

    redirect_to @scouting_entry, notice: "Entry was marked as admin approved and now counts toward scouting coverage."
  end

  # POST /scouting_entries/sync — offline sync endpoint
  def sync
    authorize :scouting_entry, :sync?

    entries_params = params.require(:entries)
    results = []
    created_event_ids = []

    entries_params.each do |entry_data|
      existing = ScoutingEntry.find_by(client_uuid: entry_data[:client_uuid])

      if existing
        # Last-Write-Wins: compare the incoming updated_at against the server's.
        # If the incoming record is newer, update; otherwise keep server copy.
        incoming_time = Time.parse(entry_data[:updated_at].to_s) rescue nil

        if incoming_time && incoming_time > existing.updated_at
          existing.update!(
            data:   entry_data[:data].is_a?(ActionController::Parameters) ? entry_data[:data].to_unsafe_h : (entry_data[:data] || {}),
            notes:  entry_data[:notes],
            status: existing.approved? ? :approved : ScoutingEntry.sync_status(entry_data[:status]),
            scouting_mode: entry_data[:scouting_mode] || existing.scouting_mode,
            video_key: entry_data[:video_key],
            video_type: entry_data[:video_type]
          )
          results << { client_uuid: entry_data[:client_uuid], status: "updated", id: existing.id }
          created_event_ids << existing.event_id
        else
          results << { client_uuid: entry_data[:client_uuid], status: "existing", id: existing.id }
        end
      else
        permitted = entry_data.permit(:match_id, :frc_team_id, :event_id, :notes, :photo_url, :client_uuid,
                                      :status, :scouting_mode, :video_key, :video_type, data: {})
                               .merge(user_id: current_user.id)

        # Validate the caller-supplied event_id references a real event
        sync_event = Event.find_by(id: permitted[:event_id])
        unless sync_event
          results << { client_uuid: entry_data[:client_uuid], status: "error", errors: [ "Invalid event" ] }
          next
        end

        entry = ScoutingEntry.from_offline_data(permitted)

        if entry.save
          results << { client_uuid: entry_data[:client_uuid], status: "created", id: entry.id }
          created_event_ids << permitted[:event_id].to_i if permitted[:event_id].present?
        else
          results << { client_uuid: entry_data[:client_uuid], status: "error", errors: entry.errors.full_messages }
        end
      end
    end

    # Refresh summaries for the events that actually received new entries
    created_event_ids.uniq.each { |eid| RefreshSummariesJob.perform_later(eid) }

    render json: { results: results }
  end

  private

  def set_scouting_entry
    @scouting_entry = policy_scope(ScoutingEntry).where(event: current_event).find(params[:id])
  end

  def scouting_entry_params
    permitted = params.require(:scouting_entry).permit(
      :match_id, :frc_team_id, :notes, :photo_url, :client_uuid, :status,
      :scouting_mode, :video_key, :video_type,
      data: {}
    )

    # The scouting form JS packs all scoring data into data[_json] as a JSON string.
    # Parse it and replace the raw data hash so the JSONB column gets real values.
    if permitted[:data].is_a?(ActionController::Parameters) && permitted[:data][:_json].present?
      permitted[:data] = JSON.parse(permitted[:data][:_json])
    end

    if permitted[:status].present?
      permitted[:status] = @scouting_entry&.approved? ? :approved : ScoutingEntry.sync_status(permitted[:status])
    end

    if replay_entry_locked?
      permitted[:scouting_mode] = @scouting_entry.scouting_mode
      permitted[:match_id] = @scouting_entry.match_id
      permitted[:frc_team_id] = @scouting_entry.frc_team_id
      permitted[:video_key] = @scouting_entry.video_key
      permitted[:video_type] = @scouting_entry.video_type
    end

    permitted
  end

  def setup_live_form(include_match: nil)
    @game_config = GameConfig.current
    @matches = ScoutableMatchesQuery.new(current_event).normal
    @matches = (@matches + [ include_match ]).compact.uniq if include_match.present?
    @matches = @matches.sort_by do |match|
      [ Match::COMP_LEVEL_ORDER.fetch(match.comp_level, 99), match.set_number.to_i, match.match_number.to_i ]
    end
    @teams = FrcTeam.at_event(current_event).order(:team_number)
    @match_teams = build_match_teams_map(@matches)
    @replay_entry_path = replay_scouting_entries_path
  end

  def set_replay_form
    @scouting_entry ||= ScoutingEntry.new(event: current_event, scouting_mode: :replay)
    match_id = replay_entry_locked? ? @scouting_entry.match_id : (params[:match_id] || @scouting_entry&.match_id)
    selected_match = replay_match_scope.find { |match| match.id == match_id.to_i }
    selected_team_id = replay_entry_locked? ? @scouting_entry.frc_team_id : (params[:frc_team_id] || @scouting_entry&.frc_team_id)

    @scouting_entry.match = selected_match if selected_match.present?
    @scouting_entry.frc_team_id = selected_team_id if selected_team_id.present?

    @game_config = GameConfig.current
    @replay_matches = replay_match_scope
    @replay_empty_state = replay_empty_state
    @coverage_map = MatchCoverageService.new(current_event).coverage_for(@replay_matches)
    @selected_match = selected_match
    @selected_video = selected_video_for(@selected_match)
    @replay_videos = @selected_match&.youtube_videos || []
    @replay_teams = replay_teams_for(@selected_match)
    @replay_submit_url = @scouting_entry.persisted? ? scouting_entry_path(@scouting_entry) : scouting_entries_path
    @replay_submit_method = @scouting_entry.persisted? ? :patch : :post
  end

  def replay_match_scope
    @replay_match_scope ||= ScoutableMatchesQuery.new(current_event).replay.select(&:replay_available?)
  end

  def replay_empty_state
    return :tba_unconfigured if current_event.tba_key.present? && !TbaClient.configured?

    qualification_matches = current_event.matches.where(comp_level: "qm").to_a
    return :no_matches if qualification_matches.empty?

    return :placeholder_schedule if qualification_matches.none?(&:best_known_time) && qualification_matches.none?(&:replay_available?)

    replay_candidates = ScoutableMatchesQuery.new(current_event).replay
    return :missing_videos if replay_candidates.any? && replay_candidates.none?(&:replay_available?)

    :default
  end

  def replay_teams_for(match)
    return [] if match.blank?

    coverage = @coverage_map[match] || { teams: [] }
    coverage[:teams].sort_by do |team|
      [
        team[:station],
        team[:alliance_color] == "blue" ? 0 : 1
      ]
    end
  end

  def selected_video_for(match)
    return if match.blank?

    video_key = selected_video_key
    return match.default_replay_video unless video_key.present?

    match.video_data_for_key(video_key) || match.default_replay_video
  end

  def selected_video_key
    return @scouting_entry.video_key if replay_entry_locked?

    params.dig(:scouting_entry, :video_key) || params[:video_key] || @scouting_entry&.video_key
  end

  def replay_entry_locked?
    @scouting_entry&.persisted? && @scouting_entry&.replay?
  end

  def success_notice_for(entry)
    return "Replay scouting entry was successfully created." if entry.replay?

    "Scouting entry was successfully created."
  end

  def replay_embed_url_for(match, raw_key)
    video = match&.video_data_for_key(raw_key)
    match&.video_embed_url(video)
  end

  def replay_watch_url_for(match, raw_key)
    video = match&.video_data_for_key(raw_key)
    match&.video_watch_url(video)
  end

  # Computes accuracy stats for this specific scouting entry by comparing the
  # scouted alliance total against the actual match score from TBA.
  def compute_entry_accuracy
    match = @scouting_entry.match
    return unless match&.red_score && match&.blue_score

    # Find which alliance this entry's team was on
    alliance = match.match_alliances.find_by(frc_team_id: @scouting_entry.frc_team_id)
    return unless alliance

    color = alliance.alliance_color
    @actual_score = color == "red" ? match.red_score : match.blue_score

    # Get all teams on this alliance
    alliance_team_ids = match.match_alliances.where(alliance_color: color).pluck(:frc_team_id)
    return if alliance_team_ids.size < 3

    # Find counted scouting entries for all 3 alliance teams in this match
    entries = match.scouting_entries.counted.where(frc_team_id: alliance_team_ids)
    entries_by_team = entries.group_by(&:frc_team_id)

    @alliance_complete = alliance_team_ids.all? { |tid| entries_by_team.key?(tid) }
    @alliance_color = color

    if @alliance_complete
      @scouted_total = alliance_team_ids.sum { |tid| entries_by_team[tid].first.total_points }
      @alliance_error = (@scouted_total - @actual_score).abs
    end

    @this_entry_points = @scouting_entry.total_points
  end

  # Returns a Hash mapping match_id to an array of team info for the team dropdown.
  # { match.id => [ { id: frc_team.id, number: 254, name: "The Cheesy Poofs", color: "red" }, ... ] }
  def build_match_teams_map(matches)
    matches.each_with_object({}) do |match, map|
      map[match.id] = match.match_alliances
        .sort_by { |ma| [ ma.alliance_color, ma.station ] }
        .map do |ma|
          {
            id: ma.frc_team.id,
            number: ma.frc_team.team_number,
            name: ma.frc_team.nickname,
            color: ma.alliance_color
          }
        end
    end
  end
end
