module Api
  module V1
    class DebugController < ApiController
      skip_before_action :authenticate_request
      skip_after_action :verify_authorized
      
      def statuses
        return head :not_found unless Rails.env.development? || Rails.env.test?

        render json: {
          booking_statuses: BookingStatus.all.as_json(only: [:id, :name, :is_active]),
          payment_statuses: PaymentStatus.all.as_json(only: [:id, :name, :is_active])
        }
      end
    end
  end
end
