class Match < ApplicationRecord
  VIDEO_TIMESTAMP_PATTERN = /\A(?<id>[A-Za-z0-9_-]+)(?:\?t=(?<seconds>\d+))?\z/

  # Associations
  belongs_to :event
  has_many :match_alliances, dependent: :destroy
  has_many :frc_teams, through: :match_alliances
  has_many :scouting_entries, dependent: :destroy
  has_many :scouting_assignments, dependent: :destroy
  has_many :predictions, dependent: :destroy

  # Scopes
  COMP_LEVEL_ORDER = { "qm" => 0, "ef" => 1, "qf" => 2, "sf" => 3, "f" => 4 }.freeze
  COMP_LEVELS = COMP_LEVEL_ORDER.keys.freeze

  # Validations (mirror DB constraints: UNIQUE(tba_key) and
  # UNIQUE(event, comp_level, set_number, match_number))
  validates :comp_level, presence: true, inclusion: { in: COMP_LEVELS }
  validates :match_number, presence: true, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validates :set_number, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validates :tba_key, uniqueness: true, allow_nil: true
  validates :match_number, uniqueness: { scope: %i[event_id comp_level set_number] }

  scope :with_scores, -> { where.not(red_score: nil, blue_score: nil) }

  scope :ordered, -> {
    order(
      Arel.sql(
        "CASE comp_level " \
        "WHEN 'qm' THEN 0 " \
        "WHEN 'ef' THEN 1 " \
        "WHEN 'qf' THEN 2 " \
        "WHEN 'sf' THEN 3 " \
        "WHEN 'f'  THEN 4 " \
        "ELSE 5 END ASC, " \
        "set_number ASC, match_number ASC"
      )
    )
  }

  # Returns a human-readable display name:
  #   qm  -> "Q1"
  #   qf  -> "QF1-1"
  #   sf  -> "SF1-1"
  #   f   -> "F1"
  def display_name
    case comp_level
    when "qm"
      "Q#{match_number}"
    when "ef"
      "EF#{set_number}-#{match_number}"
    when "qf"
      "QF#{set_number}-#{match_number}"
    when "sf"
      "SF#{set_number}-#{match_number}"
    when "f"
      "F#{match_number}"
    else
      "#{comp_level&.upcase}#{match_number}"
    end
  end

  def best_known_time
    actual_time || predicted_time || scheduled_time
  end

  def occurred?(reference_time = Time.current)
    return true if post_result_time.present? || actual_time.present?
    return false if best_known_time.blank?

    best_known_time <= reference_time
  end

  def upcoming?(reference_time = Time.current)
    !occurred?(reference_time)
  end

  def youtube_videos
    Array(videos).filter_map do |video|
      next unless video.is_a?(Hash)
      next unless video["type"] == "youtube"

      parsed = self.class.parse_video_key(video["key"])
      next unless parsed

      video.merge(parsed)
    end
  end

  def default_replay_video
    youtube_videos.first
  end

  def video_data_for_key(raw_key)
    youtube_videos.find { |video| video["raw_key"] == raw_key }
  end

  def replay_available?
    default_replay_video.present?
  end

  def video_embed_url(video = default_replay_video)
    return if video.blank?

    base = "https://www.youtube.com/embed/#{video.fetch('video_id')}"
    start_seconds = video["start_seconds"].to_i
    start_seconds.positive? ? "#{base}?start=#{start_seconds}" : base
  end

  def video_watch_url(video = default_replay_video)
    return if video.blank?

    base = "https://www.youtube.com/watch?v=#{video.fetch('video_id')}"
    start_seconds = video["start_seconds"].to_i
    start_seconds.positive? ? "#{base}&t=#{start_seconds}s" : base
  end

  def self.parse_video_key(raw_key)
    return if raw_key.blank?

    match = raw_key.match(VIDEO_TIMESTAMP_PATTERN)
    return unless match

    {
      "raw_key" => raw_key,
      "video_id" => match[:id],
      "start_seconds" => match[:seconds].to_i
    }
  end
end
