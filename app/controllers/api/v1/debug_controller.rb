module Api
  module V1
    class DebugController < ApiController
      # Require authentication — admin-only access
      before_action :require_admin!
      skip_after_action :verify_authorized

      def statuses
        # Only available in development and test environments
        return head :not_found unless Rails.env.development? || Rails.env.test?

        render json: {
          booking_statuses: BookingStatus.all.as_json(only: [:id, :name, :is_active]),
          payment_statuses: PaymentStatus.all.as_json(only: [:id, :name, :is_active])
        }
      end

      private

      def require_admin!
        unless current_user&.admin?
          render json: { error: 'Forbidden', message: 'Admin access required' }, status: :forbidden
        end
      end
    end
  end
end
