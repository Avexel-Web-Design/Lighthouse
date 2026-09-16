class PickListsController < ApplicationController
  MAX_PICK_LIST_ENTRIES = 100

  PickListTeamSummary = Struct.new(
    :frc_team_id,
    :avg_total_points,
    :fuel_accuracy_pct,
    :avg_defense_rating,
    :matches_scouted,
    keyword_init: true
  )

  PickListRecentEntry = Struct.new(
    :match_label,
    :points,
    :accuracy,
    keyword_init: true
  )

  before_action :require_event!
  before_action :set_pick_list, only: %i[show edit update destroy]
  before_action :prepare_show_data, only: :show
  before_action :load_team_options, only: %i[new create edit update]

  def index
    @pick_lists = policy_scope(PickList).where(event: current_event).includes(:user).order(updated_at: :desc)
  end

  def show
    authorize @pick_list
  end

  def new
    @pick_list = current_user.pick_lists.build(event: current_event)
    authorize @pick_list
  end

  def create
    @pick_list = current_user.pick_lists.build(pick_list_params)
    @pick_list.event = current_event
    authorize @pick_list

    if @pick_list.save
      redirect_to @pick_list, notice: "Pick list was successfully created."
    else
      load_team_options
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @pick_list
  end

  def update
    authorize @pick_list

    if @pick_list.update(pick_list_params)
      respond_to do |format|
        format.html { redirect_to @pick_list, notice: "Pick list was successfully updated." }
        format.json { render json: { id: @pick_list.id, entries: @pick_list.entries }, status: :ok }
      end
    else
      load_team_options
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @pick_list.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    authorize @pick_list
    @pick_list.destroy
    if @pick_list.destroyed?
      redirect_to pick_lists_path, notice: "Pick list was successfully deleted.", status: :see_other
    else
      redirect_to @pick_list, alert: "Could not delete pick list."
    end
  end

  private

  def set_pick_list
    @pick_list = PickList.find(params[:id])
  end

  def pick_list_params
    permitted = if params[:pick_list].present?
      params.expect(pick_list: [ :name, entries: [] ])
    else
      params.permit(:name, entries: [])
    end
    permitted[:entries] = Array(permitted[:entries]).first(MAX_PICK_LIST_ENTRIES)
    permitted[:entries] ||= []
    permitted
  end

  def prepare_show_data
    @ordered_team_ids = safe_ordered_team_ids(@pick_list)
    @teams_by_id = FrcTeam.where(id: @ordered_team_ids).index_by(&:id)
    @team_summaries, @latest_entries_by_team = build_team_metrics(@ordered_team_ids)
  rescue StandardError => e
    Rails.logger.warn("[PickListsController] Failed to prepare pick list #{@pick_list&.id} for display: #{e.class}: #{e.message}")
    @ordered_team_ids = []
    @teams_by_id = {}
    @team_summaries = {}
    @latest_entries_by_team = {}
    @team_summary_warning = true
  end

  def load_team_options
    @pick_list ||= current_user.pick_lists.build(event: current_event)

    selected_ids = safe_ordered_team_ids(@pick_list)
    teams = FrcTeam.at_event(current_event).order(:team_number).to_a
    summaries, latest_entries_by_team = build_team_metrics(teams.map(&:id))
    event_rank_by_id = summaries.values.sort_by do |summary|
      [ -summary.avg_total_points.to_f, -summary.matches_scouted.to_i, summary.frc_team_id ]
    end.each_with_index(1).to_h { |summary, index| [ summary.frc_team_id, index ] }

    sorted_teams = teams.sort_by do |team|
      selected_index = selected_ids.index(team.id)

      [
        selected_index.nil? ? 1 : 0,
        selected_index || 9_999,
        selected_index.nil? ? -summaries[team.id]&.avg_total_points.to_f : 0,
        team.team_number
      ]
    end

    @team_options = sorted_teams.map do |team|
      {
        team: team,
        summary: summaries[team.id],
        recent_entry: latest_entries_by_team[team.id],
        selected: selected_ids.include?(team.id),
        selected_rank: selected_ids.index(team.id)&.+(1),
        event_rank: event_rank_by_id[team.id]
      }
    end
  rescue StandardError => e
    @team_summary_warning = true
    Rails.logger.warn("[PickListsController] Falling back to basic pick list options for event #{current_event&.id}: #{e.class}: #{e.message}")
    @team_options = fallback_team_options
  end

  def safe_ordered_team_ids(pick_list)
    pick_list.ordered_team_ids
  rescue StandardError => e
    Rails.logger.warn("[PickListsController] Failed to normalize pick list #{pick_list&.id || 'new'} entries: #{e.class}: #{e.message}")
    []
  end

  def fallback_team_options
    selected_ids = safe_ordered_team_ids(@pick_list)

    FrcTeam.at_event(current_event).order(:team_number).map do |team|
      {
        team: team,
        summary: nil,
        recent_entry: nil,
        selected: selected_ids.include?(team.id),
        selected_rank: selected_ids.index(team.id)&.+(1),
        event_rank: nil
      }
    end
  end

  def build_team_metrics(team_ids)
    return [ {}, {} ] if team_ids.blank?

    entries_by_team = current_event.scouting_entries
                                 .counted
                                 .where(frc_team_id: team_ids)
                                 .includes(:match)
                                 .order(created_at: :desc)
                                 .to_a
                                 .group_by(&:frc_team_id)

    summaries = {}
    latest_entries = {}

    entries_by_team.each do |team_id, entries|
      summaries[team_id] = build_pick_list_summary(entries)
      latest_entries[team_id] = build_pick_list_recent_entry(entries.first)
    rescue StandardError => e
      Rails.logger.warn("[PickListsController] Failed to compute pick list metrics for team #{team_id}: #{e.class}: #{e.message}")
    end

    [ summaries, latest_entries ]
  end

  def build_pick_list_summary(entries)
    metrics = entries.filter_map { |entry| safe_entry_metrics(entry) }
    defense_ratings = metrics.map { |metric| metric[:defense_rating] }.compact.select(&:positive?)

    PickListTeamSummary.new(
      frc_team_id: entries.first.frc_team_id,
      avg_total_points: average(metrics.map { |metric| metric[:points] }),
      fuel_accuracy_pct: average(metrics.map { |metric| metric[:accuracy] }),
      avg_defense_rating: defense_ratings.any? ? average(defense_ratings) : nil,
      matches_scouted: entries.size
    )
  end

  def build_pick_list_recent_entry(entry)
    return if entry.blank?

    metrics = safe_entry_metrics(entry)
    return if metrics.blank?

    PickListRecentEntry.new(
      match_label: entry.match&.display_name,
      points: metrics[:points],
      accuracy: metrics[:accuracy]
    )
  end

  def average(values)
    return 0.0 if values.blank?

    values.sum.to_f / values.size
  end

  def safe_entry_metrics(entry)
    {
      points: entry.total_points,
      accuracy: entry.fuel_accuracy,
      defense_rating: entry.defense_rating
    }
  rescue StandardError => e
    Rails.logger.warn("[PickListsController] Failed to read scouting entry #{entry.id} for pick list metrics: #{e.class}: #{e.message}")
    nil
  end
end
