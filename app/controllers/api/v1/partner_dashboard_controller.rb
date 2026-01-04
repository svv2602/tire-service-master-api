# frozen_string_literal: true

module Api
  module V1
    # PartnerDashboardController - provides dashboard data for partners
    class PartnerDashboardController < ApiController
      before_action :authenticate_request
      before_action :ensure_partner_access!
      before_action :set_partner

      # GET /api/v1/partners/:partner_id/dashboard
      def show
        render json: {
          today_bookings: today_bookings,
          pending_count: pending_count,
          weekly_stats: weekly_stats,
          top_services: top_services,
          recent_reviews: recent_reviews,
          quick_stats: quick_stats
        }
      end

      private

      def ensure_partner_access!
        return if current_user.admin?
        return if current_user.partner?
        return if current_user.manager?
        return if current_user.operator?

        render json: { error: 'Доступ запрещён' }, status: :forbidden
      end

      def set_partner
        @partner = if current_user.admin?
                     Partner.find(params[:partner_id])
                   elsif current_user.partner?
                     current_user.partner
                   elsif current_user.manager?
                     current_user.manager&.partner
                   elsif current_user.operator?
                     current_user.operator&.partner
                   end

        render json: { error: 'Партнёр не найден' }, status: :not_found unless @partner
      end

      def today_bookings
        Rails.cache.fetch("partner_dashboard:#{@partner.id}:today_bookings", expires_in: 1.minute) do
          Booking.for_partner(@partner.id)
                 .today
                 .includes(:service_point, :service_category, client: :user)
                 .order(:start_time)
                 .map { |b| serialize_booking(b) }
        end
      end

      def pending_count
        Rails.cache.fetch("partner_dashboard:#{@partner.id}:pending_count", expires_in: 1.minute) do
          Booking.for_partner(@partner.id)
                 .where(status: 'pending')
                 .count
        end
      end

      def weekly_stats
        Rails.cache.fetch("partner_dashboard:#{@partner.id}:weekly_stats", expires_in: 5.minutes) do
          week_range = 7.days.ago.to_date..Date.current
          bookings = Booking.for_partner(@partner.id).where(booking_date: week_range)

          completed = bookings.where(status: 'completed')

          {
            total_bookings: bookings.count,
            completed_bookings: completed.count,
            cancelled_bookings: bookings.where(status: %w[cancelled_by_client cancelled_by_partner]).count,
            pending_bookings: bookings.where(status: 'pending').count,
            revenue: completed.sum(:total_price).to_f.round(2),
            average_rating: calculate_weekly_average_rating,
            bookings_by_day: bookings_by_day(week_range)
          }
        end
      end

      def top_services
        Rails.cache.fetch("partner_dashboard:#{@partner.id}:top_services", expires_in: 5.minutes) do
          month_range = 30.days.ago.to_date..Date.current

          # Get top services from completed bookings
          BookingService.joins(:booking, :service)
                        .joins('INNER JOIN service_points ON bookings.service_point_id = service_points.id')
                        .where(service_points: { partner_id: @partner.id })
                        .where(bookings: { booking_date: month_range, status: 'completed' })
                        .group('services.id, services.name')
                        .select('services.id, services.name, COUNT(*) as count, SUM(booking_services.price) as revenue')
                        .order('count DESC')
                        .limit(5)
                        .map do |row|
            {
              id: row.id,
              name: row.name,
              count: row.count,
              revenue: row.revenue.to_f.round(2)
            }
          end
        end
      end

      def recent_reviews
        Rails.cache.fetch("partner_dashboard:#{@partner.id}:recent_reviews", expires_in: 2.minutes) do
          Review.for_partner(@partner.id)
                .published
                .ordered_by_date
                .includes(:service_point, client: :user)
                .limit(5)
                .map { |r| serialize_review(r) }
        end
      end

      def quick_stats
        Rails.cache.fetch("partner_dashboard:#{@partner.id}:quick_stats", expires_in: 5.minutes) do
          {
            total_service_points: @partner.service_points.count,
            active_service_points: @partner.service_points.where(is_active: true).count,
            total_operators: @partner.operators.count,
            average_rating: @partner.average_rating.to_f.round(2),
            total_clients_served: @partner.total_clients_served
          }
        end
      end

      def calculate_weekly_average_rating
        week_range = 7.days.ago.to_date..Date.current
        reviews = Review.for_partner(@partner.id)
                        .where(created_at: week_range.first.beginning_of_day..week_range.last.end_of_day)
                        .published

        return 0.0 if reviews.count.zero?

        reviews.average(:rating).to_f.round(2)
      end

      def bookings_by_day(range)
        Booking.for_partner(@partner.id)
               .where(booking_date: range)
               .group(:booking_date)
               .count
               .transform_keys(&:to_s)
      end

      def serialize_booking(booking)
        {
          id: booking.id,
          booking_date: booking.booking_date,
          start_time: booking.start_time&.strftime('%H:%M'),
          end_time: booking.end_time&.strftime('%H:%M'),
          status: booking.status,
          client_name: booking.service_recipient_display_name || booking.client&.user&.full_name || 'Гость',
          client_phone: booking.service_recipient_phone || booking.client&.user&.phone,
          service_point_name: booking.service_point&.name,
          service_category: booking.service_category&.name,
          total_price: booking.total_price.to_f,
          car_info: format_car_info(booking)
        }
      end

      def format_car_info(booking)
        return nil unless booking.car_brand.present? || booking.license_plate.present?

        parts = []
        parts << "#{booking.car_brand} #{booking.car_model}".strip if booking.car_brand.present?
        parts << booking.license_plate if booking.license_plate.present?
        parts.join(' / ')
      end

      def serialize_review(review)
        {
          id: review.id,
          rating: review.rating,
          comment: review.comment,
          recommend: review.recommend,
          partner_response: review.partner_response,
          created_at: review.created_at,
          client_name: review.client&.user&.full_name || 'Аноним',
          service_point_name: review.service_point&.name
        }
      end
    end
  end
end
