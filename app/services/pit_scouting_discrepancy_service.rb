# frozen_string_literal: true

# Compares multiple pit scouting reports for the same team+event and returns
# only the spec fields where scouts disagree.
#
# Free-text fields (notes, strengths/weaknesses, *_notes) and auton paths are
# intentionally excluded — they almost always differ and would create noise.
# Photos are also excluded; open each report for full detail.
class PitScoutingDiscrepancyService
  # key: PitScoutingEntry method to read, label: display name, kind: comparison type
  FIELDS = [
    { key: "drivetrain", label: "Drivetrain", kind: :string },
    { key: "drive_motor", label: "Drive motor", kind: :string },
    { key: "pivot_motor", label: "Pivot motor", kind: :string },
    { key: "robot_width", label: "Robot width", kind: :numeric },
    { key: "robot_length", label: "Robot length", kind: :numeric },
    { key: "robot_height", label: "Robot height", kind: :numeric },
    { key: "robot_weight", label: "Robot weight", kind: :numeric },
    { key: "intake_types", label: "Intake types", kind: :array },
    { key: "intake_width", label: "Intake width", kind: :numeric },
    { key: "intake_mechanism_display", label: "Intake mechanism", kind: :string },
    { key: "indexer_display", label: "Indexer", kind: :string },
    { key: "shooter_types", label: "Shooter types", kind: :array },
    { key: "shooter_hood", label: "Shooter hood", kind: :string },
    { key: "shooter_motor", label: "Shooter motor", kind: :string },
    { key: "climber_levels", label: "Climber levels", kind: :array },
    { key: "climber_type", label: "Climber type", kind: :string },
    { key: "hopper_x", label: "Hopper X", kind: :numeric },
    { key: "hopper_y", label: "Hopper Y", kind: :numeric },
    { key: "hopper_z", label: "Hopper Z", kind: :numeric },
    { key: "hopper_extended_x", label: "Hopper extended X", kind: :numeric },
    { key: "hopper_extended_y", label: "Hopper extended Y", kind: :numeric },
    { key: "hopper_extended_z", label: "Hopper extended Z", kind: :numeric }
  ].freeze

  def initialize(entries)
    @entries = entries.to_a
  end

  # Returns an array of { key:, label:, reports: [{ entry:, display: }] }
  # containing only fields where the comparable (non-rejected) entries differ.
  def discrepancies
    comparable = @entries.reject { |entry| entry.respond_to?(:rejected?) && entry.rejected? }
    return [] if comparable.size < 2

    FIELDS.filter_map do |field|
      normalized = comparable.map { |entry| normalize(read(entry, field[:key]), field[:kind]) }
      next if normalized.uniq.size < 2

      {
        key: field[:key],
        label: field[:label],
        reports: comparable.map do |entry|
          { entry: entry, display: display_value(field[:key], read(entry, field[:key])) }
        end
      }
    end
  end

  private

  def read(entry, key)
    entry.public_send(key)
  end

  def normalize(value, kind)
    case kind
    when :array
      Array(value).map { |item| item.to_s.strip }.reject(&:empty?).sort
    when :numeric
      return nil if value.nil? || value.to_s.strip.empty?

      text = value.to_s.strip
      text.match?(/\A-?\d+(\.\d+)?\z/) ? text.to_f : text
    else
      text = value.to_s.strip
      text.empty? ? nil : text
    end
  end

  def display_value(key, value)
    if value.is_a?(Array)
      items = value.map(&:to_s).map(&:strip).reject(&:empty?)
      return "—" if items.empty?

      items = items.map { |item| item.humanize.titleize } if key == "intake_types"
      items.join(", ")
    else
      text = value.to_s.strip
      text.empty? ? "—" : text
    end
  end
end
