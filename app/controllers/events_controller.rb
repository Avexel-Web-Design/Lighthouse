class EventsController < ApplicationController
  MAX_MANIFEST_URLS = 500
  MIN_EVENT_YEAR = 1992
  EVENT_CODE_FORMAT = /\A[a-z0-9-]{1,20}\z/

  before_action :set_event, only: %i[show edit update destroy sync offline_manifest]

  def index
    @events = policy_scope(Event).order(start_date: :desc)
  end

  def show
    authorize @event
    @matches = @event.matches.ordered.includes(:frc_teams)
    @teams = FrcTeam.at_event(@event).order(:team_number)
  end

  def new
    @event = Event.new
    authorize @event
  end

  def create
    create_params = create_event_params
    year = create_params[:year].to_i
    event_code = create_params[:event_code].to_s.strip.downcase
    max_year = Date.current.year + 2

    unless year.between?(MIN_EVENT_YEAR, max_year) && event_code.match?(EVENT_CODE_FORMAT)
      @event = Event.new
      authorize @event
      flash.now[:alert] = "Provide a valid event year (#{MIN_EVENT_YEAR}–#{max_year}) and event code."
      render :new, status: :unprocessable_entity
      return
    end

    tba_key = "#{year}#{event_code}"
    tba_configured = TbaClient.configured?

    @event = Event.new(tba_key: tba_key, year: year)
    authorize @event

    # Fetch details from TBA to auto-populate fields
    tba_data = tba_configured ? TbaClient.new.event(tba_key) : nil
    if tba_data
      @event.assign_attributes(
        name: tba_data["name"],
        start_date: tba_data["start_date"],
        end_date: tba_data["end_date"],
        city: tba_data["city"],
        state_prov: tba_data["state_prov"],
        country: tba_data["country"],
        event_type: tba_data["event_type"],
        week: tba_data["week"]
      )
    else
      @event.name = tba_key
    end

    if @event.save
      # Auto-sync teams and matches from TBA (synchronous so data is ready immediately)
      if tba_configured
        begin
          TbaSyncService.new(tba_key).sync_all!
        rescue StandardError => e
          Rails.logger.warn("[EventsController] TBA sync failed for new event #{tba_key}: #{e.class}: #{e.message}")
        end
      end

      # Enqueue background jobs for Statbotics data, summaries, and predictions
      RefreshSummariesJob.perform_later(@event.id)
      SyncStatboticsJob.perform_later(@event.id)
      RefreshPredictionsJob.perform_later(@event.id)

      redirect_to @event, notice: create_notice_for(tba_configured)
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActionController::ParameterMissing
    @event = Event.new
    authorize @event
    flash.now[:alert] = "Provide a valid event year and event code."
    render :new, status: :unprocessable_entity
  end

  def edit
    authorize @event
  end

  def update
    authorize @event

    if @event.update(update_event_params)
      redirect_to @event, notice: "Event was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @event
    destroyed_id = @event.id
    @event.destroy
    session.delete(:current_event_id) if session[:current_event_id] == destroyed_id
    if @event.destroyed?
      redirect_to events_path, notice: "Event was successfully deleted.", status: :see_other
    else
      redirect_to @event, alert: "Could not delete event."
    end
  end

  # POST /events/:id/select — sets the current event in session
  def select
    @event = Event.find(params[:id])
    authorize @event, :select?

    session[:current_event_id] = @event.id

    redirect_to root_path, notice: "Switched to #{@event.name}."
  end

  # GET /events/:id/offline_manifest — returns JSON list of URLs to prefetch for offline use
  def offline_manifest
    authorize @event, :show?

    urls = [
      "/",
      scouting_entries_path,
      scouting_assignments_path,
      new_scouting_entry_path,
      pit_scouting_entries_path,
      new_pit_scouting_entry_path,
      teams_path,
      team_comparison_path,
      pick_lists_path,
      data_conflicts_path,
      predictions_path,
      new_match_simulator_path,
      event_path(@event)
    ]

    # Cache resource IDs to avoid repeated queries under concurrent load
    cached_ids = Rails.cache.fetch("event/#{@event.id}/offline_manifest_ids", expires_in: 5.minutes) do
      {
        team_ids: FrcTeam.at_event(@event).pluck(:id),
        match_ids: @event.matches.pluck(:id),
        scouting_entry_ids: ScoutingEntry.where(event: @event).pluck(:id),
        pit_scouting_entry_ids: PitScoutingEntry.where(event: @event).pluck(:id),
        pick_list_ids: PickList.where(event: @event).pluck(:id)
      }
    end

    urls += cached_ids[:team_ids].map { |id| team_path(id) }
    urls += cached_ids[:match_ids].map { |id| prediction_path(id) }
    urls += cached_ids[:scouting_entry_ids].map { |id| scouting_entry_path(id) }
    urls += cached_ids[:pit_scouting_entry_ids].map { |id| pit_scouting_entry_path(id) }
    urls += cached_ids[:pick_list_ids].map { |id| pick_list_path(id) }

    expires_in 5.minutes, public: false

    unique_urls = urls.uniq
    truncated = unique_urls.length > MAX_MANIFEST_URLS

    render json: {
      urls: unique_urls.first(MAX_MANIFEST_URLS),
      truncated: truncated,
      total: unique_urls.length
    }
  end

  # POST /events/:id/sync — triggers TBA sync + Statbotics cache warming + predictions
  def sync
    authorize @event, :sync?

    unless TbaClient.configured?
      redirect_to @event, alert: "TBA sync is unavailable because `TBA_API_KEY` is not configured."
      return
    end

    TbaSyncService.new(@event.tba_key).sync_all!

    # Refresh materialized views, warm Statbotics cache, and regenerate predictions
    RefreshSummariesJob.perform_later(@event.id)
    SyncStatboticsJob.perform_later(@event.id)
    RefreshPredictionsJob.perform_later(@event.id)

    redirect_to @event, notice: "Event data synced from The Blue Alliance. Statbotics data and predictions are updating in the background."
  rescue StandardError => e
    Rails.logger.warn("[EventsController] Sync failed for event #{@event&.id}: #{e.class}: #{e.message}")
    redirect_to @event, alert: "Sync failed. Please try again later."
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  def create_event_params
    params.require(:event).permit(:year, :event_code)
  end

  def update_event_params
    params.require(:event).permit(:name, :start_date, :end_date, :city, :state_prov, :country, :event_type)
  end

  def create_notice_for(tba_configured)
    return "Event created. Add `TBA_API_KEY` to enable TBA sync." unless tba_configured

    "Event created and syncing data from TBA."
  end
end
