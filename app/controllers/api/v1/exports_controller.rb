module Api
  module V1
    class ExportsController < ActionController::API
      include ApiAuthenticatable
      include Pundit::Authorization

      rescue_from Pundit::NotAuthorizedError, with: :render_forbidden

      def scouting_data
        authorize :export, :json?

        event = Event.find_by(id: params[:event_id])
        unless event
          render json: { error: "Event not found" }, status: :not_found
          return
        end

        entries = policy_scope(ScoutingEntry).where(event: event).includes(:user, :frc_team, :match)

        format = params[:format] || "json"

        case format
        when "json"
          data = entries.map do |entry|
            {
              id: entry.id,
              match: entry.match&.display_name,
              team_number: entry.frc_team.team_number,
              scout: entry.user.full_name,
              status: entry.status,
              total_points: entry.total_points,
              fuel_accuracy: entry.fuel_accuracy,
              data: entry.data,
              notes: entry.notes,
              created_at: entry.created_at.iso8601
            }
          end
          render json: { event: event.name, entries: data }
        else
          render json: { error: "Unsupported format: #{format}" }, status: :bad_request
        end
      end

      private

      def pundit_user
        current_api_user
      end

      def render_forbidden
        render json: { error: "Forbidden" }, status: :forbidden
      end
    end
  end
end
