module Api
  module V1
    class PitScoutingEntriesController < ActionController::API
      include ApiAuthenticatable

      MAX_BULK_SYNC = 100
      PIT_DATA_KEYS = %i[
        robot_width robot_length robot_height robot_weight
        drivetrain drive_motor pivot_motor drivetrain_notes
        intake_width intake_mechanism intake_mechanism_other intake_notes
        hopper_x hopper_y hopper_z
        hopper_extended_x hopper_extended_y hopper_extended_z hopper_notes
        indexer indexer_other indexer_notes
        shooter_hood shooter_motor shooter_notes
        climber_type climber_notes
        auton_notes strengths weaknesses
      ].freeze

      def create
        entry = PitScoutingEntry.from_offline_data(
          entry_params.merge(user_id: current_api_user.id)
        )

        if entry.client_uuid.present?
          existing = PitScoutingEntry.find_by(client_uuid: entry.client_uuid)
          if existing
            render json: { status: "existing", id: existing.id, client_uuid: existing.client_uuid }, status: :ok
            return
          end
        end

        if entry.save
          render json: { status: "created", id: entry.id, client_uuid: entry.client_uuid }, status: :created
        else
          render json: { status: "error", errors: entry.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def bulk_sync
        entries_data = params.require(:entries)
        unless entries_data.is_a?(Array) && entries_data.size <= MAX_BULK_SYNC
          render json: { error: "Too many entries (max #{MAX_BULK_SYNC})." }, status: :unprocessable_entity
          return
        end

        results = []

        entries_data.each do |entry_data|
          permitted = entry_data.permit(
            :event_id, :frc_team_id,
            :notes, :client_uuid, :status
          ).merge(user_id: current_api_user.id)
          permitted[:data] = sanitize_api_data(entry_data[:data])
          permitted[:notes] = permitted[:notes].to_s.strip.first(2000) if permitted[:notes].present?

          existing = PitScoutingEntry.find_by(client_uuid: permitted[:client_uuid]) if permitted[:client_uuid].present?

          if existing
            results << { client_uuid: permitted[:client_uuid], status: "existing", id: existing.id }
          else
            entry = PitScoutingEntry.from_offline_data(permitted)
            if entry.save
              results << { client_uuid: permitted[:client_uuid], status: "created", id: entry.id }
            else
              results << { client_uuid: permitted[:client_uuid], status: "error", errors: entry.errors.full_messages }
            end
          end
        end

        render json: { results: results }
      end

      private

      def entry_params
        permitted = params.require(:pit_scouting_entry).permit(
          :event_id, :frc_team_id,
          :notes, :client_uuid, :status
        )
        permitted[:data] = sanitize_api_data(params.dig(:pit_scouting_entry, :data))
        permitted[:notes] = permitted[:notes].to_s.strip.first(2000) if permitted[:notes].present?
        permitted
      end

      def sanitize_api_data(raw)
        source = raw.is_a?(ActionController::Parameters) ? raw.permit(*PIT_DATA_KEYS, intake_types: [], shooter_types: [], climber_levels: []).to_h : raw.to_h
        result = {}
        PIT_DATA_KEYS.each do |key|
          value = source[key.to_s].nil? ? source[key] : source[key.to_s]
          result[key.to_s] = value unless value.nil?
        end
        %w[intake_types shooter_types climber_levels].each do |key|
          values = source[key] || source[key.to_s]
          result[key] = Array(values).map(&:to_s).map { |v| v.first(100) }.first(20) if values.present?
        end
        result
      end
    end
  end
end
