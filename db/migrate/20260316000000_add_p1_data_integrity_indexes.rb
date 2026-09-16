class AddP1DataIntegrityIndexes < ActiveRecord::Migration[8.1]
  def up
    # Hot query paths: event-scoped entry lists and per-team history.
    add_index :scouting_entries, %i[event_id status],
              name: "idx_scouting_entries_event_status"
    add_index :scouting_entries, %i[event_id frc_team_id created_at],
              name: "idx_scouting_entries_event_team_created"

    # Guards Event#ensure_qualification_matches! and TbaSyncService against
    # concurrent duplicate scaffolds (rescued as RecordNotUnique).
    add_index :matches, %i[event_id comp_level set_number match_number],
              unique: true, name: "idx_matches_event_comp_set_number"

    # Conflict queue lookups are always event-scoped by resolution state.
    add_index :data_conflicts, %i[event_id resolved],
              name: "idx_data_conflicts_event_resolved"

    # Enforces the case-insensitive username validation at the DB level.
    # The pre-existing case-sensitive unique index is kept for exact-match
    # lookups; this expression index is the integrity guard.
    add_index :users, "LOWER(username)",
              unique: true, name: "index_users_on_lower_username"

    # Redundant pair: UNIQUE(endpoint) implies UNIQUE(user_id, endpoint), and
    # the controller treats endpoint as globally unique
    # (find_or_initialize_by(endpoint:), reassigning ownership on re-subscribe).
    # Keeping endpoint-only uniqueness additionally prevents one browser
    # subscription from being registered to two users, which would misroute
    # pushes. Drops the implied composite index.
    remove_index :web_push_subscriptions,
                 name: "idx_web_push_subscriptions_user_endpoint"

    rebuild_team_event_summaries!
  end

  def down
    add_index :web_push_subscriptions, %i[user_id endpoint],
              unique: true, name: "idx_web_push_subscriptions_user_endpoint"
    remove_index :users, name: "index_users_on_lower_username"
    remove_index :data_conflicts, name: "idx_data_conflicts_event_resolved"
    remove_index :matches, name: "idx_matches_event_comp_set_number"
    remove_index :scouting_entries, name: "idx_scouting_entries_event_team_created"
    remove_index :scouting_entries, name: "idx_scouting_entries_event_status"
    # team_event_summaries definition is unchanged in net terms (same counted
    # statuses), so down leaves the view as-is.
  end

  private

  # Rebuilds team_event_summaries with the counted statuses derived from the
  # ScoutingEntry enum instead of hardcoded magic numbers. Evaluated when the
  # migration runs; the resulting SQL matches the previous `status IN (0, 3)`.
  def rebuild_team_event_summaries!
    counted = ScoutingEntry.statuses.values_at("submitted", "approved")
    status_sql = "status IN (#{counted.join(", ")})" # e.g. status IN (0, 3)

    execute "DROP MATERIALIZED VIEW IF EXISTS team_event_summaries"

    execute <<~SQL
      CREATE MATERIALIZED VIEW team_event_summaries AS
      SELECT
        event_id,
        frc_team_id,
        COUNT(*) AS matches_scouted,
        AVG(
          COALESCE((data->>'auton_fuel_made')::numeric, 0) +
          COALESCE((data->>'teleop_fuel_made')::numeric, 0) +
          COALESCE((data->>'endgame_fuel_made')::numeric, 0)
        ) AS avg_fuel_made,
        AVG(
          COALESCE((data->>'auton_fuel_missed')::numeric, 0) +
          COALESCE((data->>'teleop_fuel_missed')::numeric, 0) +
          COALESCE((data->>'endgame_fuel_missed')::numeric, 0)
        ) AS avg_fuel_missed,
        CASE
          WHEN SUM(
            COALESCE((data->>'auton_fuel_made')::numeric, 0) +
            COALESCE((data->>'teleop_fuel_made')::numeric, 0) +
            COALESCE((data->>'endgame_fuel_made')::numeric, 0) +
            COALESCE((data->>'auton_fuel_missed')::numeric, 0) +
            COALESCE((data->>'teleop_fuel_missed')::numeric, 0) +
            COALESCE((data->>'endgame_fuel_missed')::numeric, 0)
          ) > 0
          THEN ROUND(
            SUM(
              COALESCE((data->>'auton_fuel_made')::numeric, 0) +
              COALESCE((data->>'teleop_fuel_made')::numeric, 0) +
              COALESCE((data->>'endgame_fuel_made')::numeric, 0)
            ) * 100.0 /
            NULLIF(SUM(
              COALESCE((data->>'auton_fuel_made')::numeric, 0) +
              COALESCE((data->>'teleop_fuel_made')::numeric, 0) +
              COALESCE((data->>'endgame_fuel_made')::numeric, 0) +
              COALESCE((data->>'auton_fuel_missed')::numeric, 0) +
              COALESCE((data->>'teleop_fuel_missed')::numeric, 0) +
              COALESCE((data->>'endgame_fuel_missed')::numeric, 0)
            ), 0), 1)
          ELSE 0
        END AS fuel_accuracy_pct,
        AVG(
          CASE WHEN (data->>'auton_climb')::boolean THEN 15 ELSE 0 END +
          CASE data->>'endgame_climb'
            WHEN 'L3' THEN 30
            WHEN 'L2' THEN 20
            WHEN 'L1' THEN 10
            ELSE 0
          END
        ) AS avg_climb_points,
        AVG(
          COALESCE((data->>'auton_fuel_made')::numeric, 0) +
          COALESCE((data->>'teleop_fuel_made')::numeric, 0) +
          COALESCE((data->>'endgame_fuel_made')::numeric, 0) +
          CASE WHEN (data->>'auton_climb')::boolean THEN 15 ELSE 0 END +
          CASE data->>'endgame_climb'
            WHEN 'L3' THEN 30
            WHEN 'L2' THEN 20
            WHEN 'L1' THEN 10
            ELSE 0
          END
        ) AS avg_total_points,
        STDDEV_SAMP(
          COALESCE((data->>'auton_fuel_made')::numeric, 0) +
          COALESCE((data->>'teleop_fuel_made')::numeric, 0) +
          COALESCE((data->>'endgame_fuel_made')::numeric, 0) +
          CASE WHEN (data->>'auton_climb')::boolean THEN 15 ELSE 0 END +
          CASE data->>'endgame_climb'
            WHEN 'L3' THEN 30
            WHEN 'L2' THEN 20
            WHEN 'L1' THEN 10
            ELSE 0
          END
        ) AS stddev_total_points,
        AVG(
          COALESCE((data->>'auton_fuel_made')::numeric, 0) +
          CASE WHEN (data->>'auton_climb')::boolean THEN 15 ELSE 0 END
        ) AS avg_auton_points,
        AVG(NULLIF(COALESCE((data->>'defense_rating')::numeric, 0), 0)) AS avg_defense_rating,
        MAX(updated_at) AS last_updated
      FROM scouting_entries
      WHERE #{status_sql}
      GROUP BY event_id, frc_team_id
      WITH NO DATA
    SQL

    add_index :team_event_summaries, [ :event_id, :frc_team_id ],
              unique: true, name: "idx_team_event_summaries"

    execute "REFRESH MATERIALIZED VIEW team_event_summaries"
  end
end
