module Api
  module V1
    class PitScoutingEntriesController < ActionController::API
      include ApiAuthenticatable
      include JsonRequestData

      MAX_BULK_SYNC = 100

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
        entries_data = params[:entries]
        unless entries_data.is_a?(Array) && entries_data.size <= MAX_BULK_SYNC
          render json: { error: "Too many entries (max #{MAX_BULK_SYNC})." }, status: :unprocessable_entity
          return
        end

        results = []

        entries_data.each do |entry_data|
          unless entry_data.is_a?(ActionController::Parameters)
            results << { client_uuid: nil, status: "error", errors: [ "Entry must be an object" ] }
            next
          end

          permitted = entry_data.permit(
            :event_id, :frc_team_id,
            :notes, :client_uuid, :status
          ).merge(user_id: current_api_user.id)
          permitted[:data] = json_request_data(entry_data[:data])
          permitted[:notes] = permitted[:notes].to_s.strip.first(2000) if permitted[:notes].present?

          existing = permitted[:client_uuid].present? ? PitScoutingEntry.find_by(client_uuid: permitted[:client_uuid]) : nil

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
        rescue ActionController::BadRequest, ArgumentError, ActiveRecord::RecordNotUnique => e
          Rails.logger.warn("[Api::V1::PitScoutingEntriesController] Sync row failed: #{e.class}")
          results << { client_uuid: permitted&.[](:client_uuid), status: "error", errors: [ "Could not save entry" ] }
        end

        render json: { results: results }
      end

      private

      def entry_params
        permitted = params.expect(pit_scouting_entry: [
          :event_id, :frc_team_id,
          :notes, :client_uuid, :status
        ])
        permitted[:data] = json_request_data(params.dig(:pit_scouting_entry, :data))
        permitted[:notes] = permitted[:notes].to_s.strip.first(2000) if permitted[:notes].present?
        permitted
      end
    end
  end
end
