# frozen_string_literal: true

module Api
  module V1
    class ReviewRequestsController < ApiController
      skip_after_action :verify_authorized
      before_action :authenticate_user!, except: [:show_by_token, :submit_review]
      before_action :ensure_partner_access, only: [:index, :stats, :settings, :update_settings, :send_manual]
      before_action :set_partner, only: [:index, :stats, :settings, :update_settings, :send_manual]

      # GET /api/v1/partners/:partner_id/review_requests
      # List review requests for partner
      def index
        requests = partner_review_requests
                     .includes(booking: [:service_point, client: :user])
                     .order(created_at: :desc)

        # Filter by status
        if params[:status].present?
          requests = case params[:status]
                     when 'pending' then requests.active
                     when 'used' then requests.used
                     when 'expired' then requests.expired
                     else requests
                     end
        end

        # Filter by service point
        if params[:service_point_id].present?
          requests = requests.joins(:booking).where(bookings: { service_point_id: params[:service_point_id] })
        end

        # Pagination
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 20).to_i

        total = requests.count
        requests = requests.offset((page - 1) * per_page).limit(per_page)

        render json: {
          data: requests.map { |r| serialize_review_request(r) },
          pagination: {
            current_page: page,
            per_page: per_page,
            total_count: total,
            total_pages: (total.to_f / per_page).ceil
          }
        }
      end

      # GET /api/v1/partners/:partner_id/review_requests/stats
      # Statistics for review requests
      def stats
        period_start = params[:from_date]&.to_date || 30.days.ago.to_date
        period_end = params[:to_date]&.to_date || Date.current

        requests = partner_review_requests.where(created_at: period_start.beginning_of_day..period_end.end_of_day)
        completed_bookings = partner_completed_bookings(period_start, period_end)

        sent_count = requests.count
        used_count = requests.used.count
        expired_count = requests.expired.count
        reviews_count = partner_reviews_count(period_start, period_end)

        render json: {
          period: {
            from: period_start.strftime('%Y-%m-%d'),
            to: period_end.strftime('%Y-%m-%d')
          },
          stats: {
            completed_bookings: completed_bookings.count,
            requests_sent: sent_count,
            requests_used: used_count,
            requests_expired: expired_count,
            reviews_received: reviews_count,
            conversion_rate: sent_count > 0 ? (reviews_count.to_f / sent_count * 100).round(1) : 0,
            coverage_rate: completed_bookings.count > 0 ? (sent_count.to_f / completed_bookings.count * 100).round(1) : 0
          }
        }
      end

      # GET /api/v1/partners/:partner_id/review_requests/settings
      # Get review request settings
      def settings
        settings_data = @partner.service_points.map do |sp|
          settings = sp.review_request_settings || default_settings
          {
            service_point_id: sp.id,
            service_point_name: sp.name,
            enabled: settings['enabled'] != false,
            delay_hours: settings['delay_hours'] || 24,
            send_sms: settings['send_sms'] != false,
            send_email: settings['send_email'] != false,
            custom_message: settings['custom_message']
          }
        end

        render json: {
          partner_id: @partner.id,
          global_enabled: @partner.review_requests_enabled?,
          service_points: settings_data
        }
      end

      # PATCH /api/v1/partners/:partner_id/review_requests/settings
      # Update review request settings
      def update_settings
        if params[:service_point_id].present?
          update_service_point_settings
        else
          update_partner_settings
        end
      end

      # POST /api/v1/partners/:partner_id/review_requests/send_manual
      # Manually send review request for a specific booking
      def send_manual
        booking_id = params[:booking_id]
        booking = partner_bookings.find_by(id: booking_id)

        unless booking
          render json: { error: 'Booking not found' }, status: :not_found
          return
        end

        unless booking.status == 'completed'
          render json: { error: 'Can only send review requests for completed bookings' }, status: :unprocessable_entity
          return
        end

        if booking.review.present?
          render json: { error: 'Review already exists for this booking' }, status: :unprocessable_entity
          return
        end

        # Force send review request
        ReviewRequestJob.perform_later(booking.id)

        render json: {
          success: true,
          message: 'Review request scheduled for sending',
          booking_id: booking.id
        }
      end

      # GET /api/v1/review_requests/:token
      # Get booking info by review token (public endpoint)
      def show_by_token
        token_record = ReviewRequestToken.find_valid_token(params[:token])

        unless token_record
          render json: { error: 'Invalid or expired token' }, status: :not_found
          return
        end

        booking = token_record.booking
        service_point = booking.service_point

        render json: {
          valid: true,
          booking: {
            id: booking.id,
            date: booking.booking_date.strftime('%Y-%m-%d'),
            services: booking.services.pluck(:name)
          },
          service_point: {
            id: service_point.id,
            name: service_point.name,
            address: service_point.address,
            city: service_point.city&.name
          }
        }
      end

      # POST /api/v1/review_requests/:token/submit
      # Submit review via token (public endpoint)
      def submit_review
        token_record = ReviewRequestToken.find_valid_token(params[:token])

        unless token_record
          render json: { error: 'Invalid or expired token' }, status: :not_found
          return
        end

        booking = token_record.booking

        if booking.review.present?
          render json: { error: 'Review already submitted' }, status: :unprocessable_entity
          return
        end

        review = booking.build_review(
          service_point_id: booking.service_point_id,
          client_id: booking.client_id,
          rating: params[:rating],
          comment: params[:comment],
          author_name: params[:author_name] || booking.service_recipient_full_name,
          status: 'pending'
        )

        if review.save
          # Mark token as used
          token_record.mark_as_used!(
            ip_address: request.remote_ip,
            user_agent: request.user_agent
          )

          render json: {
            success: true,
            message: 'Thank you for your review!',
            review_id: review.id
          }, status: :created
        else
          render json: { errors: review.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def ensure_partner_access
        unless current_user&.partner? || current_user&.manager? || current_user&.admin?
          render json: { error: 'Access denied' }, status: :forbidden
        end
      end

      def set_partner
        if current_user.admin?
          @partner = Partner.find(params[:partner_id])
        else
          @partner = current_user.partner
          if params[:partner_id].to_i != @partner.id
            render json: { error: 'Access denied' }, status: :forbidden
          end
        end
      end

      def partner_bookings
        Booking.joins(:service_point).where(service_points: { partner_id: @partner.id })
      end

      def partner_review_requests
        ReviewRequestToken.joins(booking: :service_point)
                          .where(service_points: { partner_id: @partner.id })
      end

      def partner_completed_bookings(from_date, to_date)
        partner_bookings.where(status: 'completed')
                        .where(booking_date: from_date..to_date)
      end

      def partner_reviews_count(from_date, to_date)
        Review.joins(:service_point)
              .where(service_points: { partner_id: @partner.id })
              .where(created_at: from_date.beginning_of_day..to_date.end_of_day)
              .count
      end

      def serialize_review_request(request)
        {
          id: request.id,
          token: request.token,
          status: request_status(request),
          created_at: request.created_at.iso8601,
          expires_at: request.expires_at.iso8601,
          used_at: request.used_at&.iso8601,
          booking: {
            id: request.booking.id,
            date: request.booking.booking_date.strftime('%Y-%m-%d'),
            client_name: request.booking.service_recipient_full_name,
            client_phone: request.booking.service_recipient_phone,
            service_point_name: request.booking.service_point&.name
          }
        }
      end

      def request_status(request)
        if request.used?
          'used'
        elsif request.expired?
          'expired'
        else
          'pending'
        end
      end

      def default_settings
        {
          'enabled' => true,
          'delay_hours' => 24,
          'send_sms' => true,
          'send_email' => true
        }
      end

      def update_service_point_settings
        service_point = @partner.service_points.find_by(id: params[:service_point_id])

        unless service_point
          render json: { error: 'Service point not found' }, status: :not_found
          return
        end

        settings = service_point.review_request_settings || {}
        settings['enabled'] = params[:enabled] if params.key?(:enabled)
        settings['delay_hours'] = params[:delay_hours].to_i if params.key?(:delay_hours)
        settings['send_sms'] = params[:send_sms] if params.key?(:send_sms)
        settings['send_email'] = params[:send_email] if params.key?(:send_email)
        settings['custom_message'] = params[:custom_message] if params.key?(:custom_message)

        service_point.update(review_request_settings: settings)

        render json: {
          success: true,
          service_point_id: service_point.id,
          settings: settings
        }
      end

      def update_partner_settings
        @partner.update(review_requests_enabled: params[:enabled]) if params.key?(:enabled)

        render json: {
          success: true,
          partner_id: @partner.id,
          enabled: @partner.review_requests_enabled?
        }
      end
    end
  end
end
