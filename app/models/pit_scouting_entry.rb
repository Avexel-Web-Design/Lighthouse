# frozen_string_literal: true

class PitScoutingEntry < ApplicationRecord
  belongs_to :event
  belongs_to :frc_team
  belongs_to :user

  has_many_attached :photos

  enum :status, { submitted: 0, flagged: 1, rejected: 2, approved: 3 }

  # client_uuid follows the same nullable-global-unique contract as
  # ScoutingEntry; (event, frc_team, user) mirrors idx_pit_scouting_entries_unique.
  normalizes :client_uuid, with: ->(uuid) { uuid.presence }
  validates :client_uuid, uniqueness: true, allow_nil: true
  validates :frc_team_id, uniqueness: { scope: %i[event_id user_id] }

  # --- Robot Specs ---
  def robot_width  = data&.dig("robot_width")
  def robot_length = data&.dig("robot_length")
  def robot_height = data&.dig("robot_height")
  def robot_weight = data&.dig("robot_weight")

  # --- Drivetrain ---
  def drivetrain       = data&.dig("drivetrain") || "Unknown"
  def drive_motor      = data&.dig("drive_motor")
  def pivot_motor      = data&.dig("pivot_motor")
  def drivetrain_notes = data&.dig("drivetrain_notes") || ""

  # --- Intake ---
  def intake_types           = data&.dig("intake_types") || []
  def intake_width           = data&.dig("intake_width")
  def intake_mechanism       = data&.dig("intake_mechanism")
  def intake_mechanism_other = data&.dig("intake_mechanism_other")
  def intake_notes           = data&.dig("intake_notes") || ""

  def intake_mechanism_display
    return intake_mechanism_other.presence || "Other" if intake_mechanism == "Other"
    intake_mechanism
  end

  # --- Hopper ---
  def hopper_x          = data&.dig("hopper_x")
  def hopper_y          = data&.dig("hopper_y")
  def hopper_z          = data&.dig("hopper_z")
  def hopper_extended_x = data&.dig("hopper_extended_x")
  def hopper_extended_y = data&.dig("hopper_extended_y")
  def hopper_extended_z = data&.dig("hopper_extended_z")
  def hopper_notes      = data&.dig("hopper_notes") || ""

  # --- Indexer ---
  def indexer       = data&.dig("indexer")
  def indexer_other = data&.dig("indexer_other")
  def indexer_notes = data&.dig("indexer_notes") || ""

  def indexer_display
    return indexer_other.presence || "Other" if indexer == "Other"
    indexer
  end

  # --- Shooter ---
  def shooter_types  = data&.dig("shooter_types") || []
  def shooter_hood   = data&.dig("shooter_hood")
  def shooter_motor  = data&.dig("shooter_motor")
  def shooter_notes  = data&.dig("shooter_notes") || ""

  # --- Climber ---
  def climber_levels = data&.dig("climber_levels") || []
  def climber_type   = data&.dig("climber_type")
  def climber_notes  = data&.dig("climber_notes") || ""

  # --- Auto ---
  def auton_paths = data&.dig("auton_paths") || []
  def auton_notes = data&.dig("auton_notes") || ""

  # --- General ---
  def strengths  = data&.dig("strengths") || ""
  def weaknesses = data&.dig("weaknesses") || ""

  # Build from offline sync data
  def self.from_offline_data(params)
    new(
      user_id: params[:user_id],
      event_id: params[:event_id],
      frc_team_id: params[:frc_team_id],
      data: params[:data] || {},
      notes: params[:notes],
      client_uuid: params[:client_uuid],
      status: params[:status] || :submitted
    )
  end
end
