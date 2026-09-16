module Api
  module V1
    class ScoutingEntriesController < ActionController::API
      include ApiAuthenticatable

      MAX_BULK_SYNC = 100
      SCOUTING_DATA_KEYS = %i[
        auton_fuel_made auton_fuel_missed
        teleop_fuel_made teleop_fuel_missed
        endgame_fuel_made endgame_fuel_missed
        auton_climb endgame_climb defense_rating
      ].freeze

      def create
        entry = ScoutingEntry.from_offline_data(
          entry_params.merge(user_id: current_api_user.id)
        )

        if entry.client_uuid.present?
          existing = ScoutingEntry.find_by(client_uuid: entry.client_uuid)
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
            :match_id, :frc_team_id, :event_id,
            :notes, :photo_url, :client_uuid, :status,
            :scouting_mode, :video_key, :video_type
          ).merge(user_id: current_api_user.id)
          permitted[:data] = sanitize_api_data(entry_data[:data])
          permitted[:notes] = permitted[:notes].to_s.strip.first(2000) if permitted[:notes].present?

          existing = ScoutingEntry.find_by(client_uuid: permitted[:client_uuid]) if permitted[:client_uuid].present?

          if existing
            results << { client_uuid: permitted[:client_uuid], status: "existing", id: existing.id }
          else
            entry = ScoutingEntry.from_offline_data(permitted)
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
        permitted = params.require(:scouting_entry).permit(
          :match_id, :frc_team_id, :event_id,
          :notes, :photo_url, :client_uuid, :status,
          :scouting_mode, :video_key, :video_type
        )
        permitted[:data] = sanitize_api_data(params.dig(:scouting_entry, :data))
        permitted[:notes] = permitted[:notes].to_s.strip.first(2000) if permitted[:notes].present?

        permitted[:status] = ScoutingEntry.sync_status(permitted[:status])
        permitted
      end

      def sanitize_api_data(raw)
        source = raw.is_a?(ActionController::Parameters) ? raw.permit(*SCOUTING_DATA_KEYS, auton_path: [], auton_actions: []).to_h : raw.to_h
        result = {}
        SCOUTING_DATA_KEYS.each do |key|
          value = source[key.to_s].nil? ? source[key] : source[key.to_s]
          result[key.to_s] = value unless value.nil?
        end
        raw_path = source["auton_path"] || source[:auton_path]
        result["auton_path"] = Array(raw_path).first(50) if raw_path.is_a?(Array)
        result
      end
    end
  end
end
