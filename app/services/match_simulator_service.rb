# frozen_string_literal: true

class MatchSimulatorService
  ITERATIONS = 1000
  DEFAULT_STDDEV = 5.0
  # Fallback EPA when both scouting and Statbotics data are unavailable
  FALLBACK_EPA = 20.0

  def initialize(event, statbotics: nil, rng: Random.new, iterations: ITERATIONS)
    @event = event
    @aggregation_service = AggregationService.new(event)
    @statbotics = statbotics
    @rng = rng
    @default_iterations = iterations
  end

  # Runs a Monte Carlo simulation for a hypothetical match.
  #
  # @param red_teams [Array<FrcTeam>] 3 teams on the red alliance
  # @param blue_teams [Array<FrcTeam>] 3 teams on the blue alliance
  # @param iterations [Integer] Monte Carlo runs (defaults to constructor value)
  # @param rng [#rand] injectable RNG for deterministic tests (defaults to constructor RNG)
  # @return [Hash] simulation results including per-team stats
  def simulate(red_teams, blue_teams, iterations: @default_iterations, rng: @rng)
    iterations = iterations.to_i.clamp(1, 10_000)
    red_stats = red_teams.map { |t| team_stats(t) }
    blue_stats = blue_teams.map { |t| team_stats(t) }

    red_wins = 0.0
    blue_wins = 0.0
    red_scores = []
    blue_scores = []

    iterations.times do
      red_score = red_stats.sum { |s| sample_score(s[:avg], s[:stddev], rng) }
      blue_score = blue_stats.sum { |s| sample_score(s[:avg], s[:stddev], rng) }

      red_scores << red_score
      blue_scores << blue_score

      if red_score > blue_score
        red_wins += 1
      elsif blue_score > red_score
        blue_wins += 1
      else
        # Tie: half-credit to each
        red_wins += 0.5
        blue_wins += 0.5
      end
    end

    red_avg = (red_scores.sum / iterations.to_f).round(2)
    blue_avg = (blue_scores.sum / iterations.to_f).round(2)

    {
      red_avg: red_avg,
      blue_avg: blue_avg,
      red_win_pct: (red_wins / iterations.to_f * 100).round(1),
      blue_win_pct: (blue_wins / iterations.to_f * 100).round(1),
      margin_of_victory: (red_avg - blue_avg).abs.round(2),
      red_team_stats: red_stats,
      blue_team_stats: blue_stats
    }
  end

  private

  def team_stats(frc_team)
    agg = @aggregation_service.aggregate_team(frc_team)

    # If we have real scouting data, use it
    if agg[:matches_scouted] > 0
      {
        team: frc_team,
        avg: agg[:avg_total_points],
        stddev: agg[:stddev_total_points].positive? ? agg[:stddev_total_points] : DEFAULT_STDDEV,
        source: :scouting,
        matches: agg[:matches_scouted]
      }
    else
      # Fall back to Statbotics EPA data
      epa = fetch_statbotics_epa(frc_team)
      if epa
        {
          team: frc_team,
          avg: epa[:mean],
          stddev: epa[:sd].positive? ? epa[:sd] : DEFAULT_STDDEV,
          source: :statbotics
        }
      else
        # No data at all — use conservative fallback
        {
          team: frc_team,
          avg: FALLBACK_EPA,
          stddev: DEFAULT_STDDEV,
          source: :fallback
        }
      end
    end
  end

  # Reads Statbotics EPA from the local DB cache (instant).
  # Falls back to the API only if no cached data exists.
  # Returns { mean:, sd: } or nil.
  def fetch_statbotics_epa(frc_team)
    # Fast path: read from local DB
    cache = StatboticsCache.find_by(event: @event, frc_team: frc_team)
    if cache&.epa_mean&.positive?
      return { mean: cache.epa_mean, sd: cache.epa_sd.to_f }
    end

    # Slow fallback: hit the API (only if a client was provided)
    return nil unless @statbotics && @event.year.present?

    data = @statbotics.team_year(frc_team.team_number, @event.year)
    return nil unless data.is_a?(Hash)

    epa = data.dig("epa", "total_points")
    return nil unless epa

    {
      mean: epa["mean"].to_f,
      sd: epa["sd"].to_f
    }
  rescue StandardError => e
    Rails.logger.warn("[MatchSimulatorService] Statbotics EPA fetch failed for team #{frc_team.team_number}: #{e.message}")
    nil
  end

  # Samples from a normal distribution using the Box-Muller transform.
  # Clamps the result to a minimum of 0 (no negative scores).
  def sample_score(mean, stddev, rng = @rng)
    u1 = rng.rand
    u1 = Float::EPSILON if u1 <= 0
    u2 = rng.rand
    z = Math.sqrt(-2.0 * Math.log(u1)) * Math.cos(2.0 * Math::PI * u2)
    [ mean + z * stddev, 0 ].max
  end
end
