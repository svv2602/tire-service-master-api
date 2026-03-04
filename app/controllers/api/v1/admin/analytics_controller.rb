# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Admin analytics dashboard controller
      # Provides overview metrics, funnel, financial and geography data
      class AnalyticsController < AdminController
        skip_after_action :verify_authorized

        # GET /api/v1/admin/analytics/overview
        # Returns key platform metrics for the admin dashboard
        def overview
          period = parse_period

          cached_response(:overview, period) do
            {
              active_users: active_users_metrics(period),
              bookings: bookings_metrics(period),
              tire_orders: tire_orders_metrics(period),
              new_partners: new_entity_count(Partner, period),
              new_suppliers: new_entity_count(Supplier, period),
              new_clients: new_entity_count(Client, period),
              bookings_trend: bookings_trend_data(period)
            }
          end
        end

        # GET /api/v1/admin/analytics/funnel
        # Returns conversion funnel data:
        # Search -> View -> Booking -> Completed -> Review
        def funnel
          period = parse_period

          cached_response(:funnel, period) do
            start_date = period_start_date(period)

            searches = estimate_searches(start_date)
            bookings_created = Booking.where(created_at: start_date..Time.current).count
            bookings_confirmed = Booking.where(created_at: start_date..Time.current)
                                        .where(status: %w[confirmed in_progress completed]).count
            bookings_completed = Booking.where(created_at: start_date..Time.current)
                                        .where(status: 'completed').count
            reviews_count = Review.where(created_at: start_date..Time.current).count

            {
              steps: [
                { name: 'search', value: searches, label: 'Search STO' },
                { name: 'booking_created', value: bookings_created, label: 'Booking Created' },
                { name: 'booking_confirmed', value: bookings_confirmed, label: 'Booking Confirmed' },
                { name: 'booking_completed', value: bookings_completed, label: 'Booking Completed' },
                { name: 'review_left', value: reviews_count, label: 'Review Left' }
              ],
              conversion_rates: {
                search_to_booking: safe_percent(bookings_created, searches),
                booking_to_confirmed: safe_percent(bookings_confirmed, bookings_created),
                confirmed_to_completed: safe_percent(bookings_completed, bookings_confirmed),
                completed_to_review: safe_percent(reviews_count, bookings_completed)
              }
            }
          end
        end

        # GET /api/v1/admin/analytics/financial
        # Returns financial metrics: revenue, average check, platform commission
        def financial
          period = parse_period

          cached_response(:financial, period) do
            start_date = period_start_date(period)

            # Booking revenue
            completed_bookings = Booking.where(created_at: start_date..Time.current, status: 'completed')
            booking_revenue = completed_bookings.sum(:total_price).to_f
            booking_count = completed_bookings.count
            booking_avg_check = booking_count > 0 ? (booking_revenue / booking_count).round(2) : 0

            # Tire order revenue
            completed_orders = TireOrder.where(created_at: start_date..Time.current)
                                        .where.not(status: %w[draft cancelled])
            order_revenue = completed_orders.sum(:total_amount).to_f
            order_count = completed_orders.count
            order_avg_check = order_count > 0 ? (order_revenue / order_count).round(2) : 0

            # Total
            total_revenue = booking_revenue + order_revenue

            # Platform commission (from partner rewards)
            total_commission = PartnerReward.where(created_at: start_date..Time.current).sum(:amount).to_f

            # Revenue trend by day (last 30 days for chart)
            revenue_trend = booking_revenue_by_day(start_date)

            {
              total_revenue: total_revenue.round(2),
              booking_revenue: booking_revenue.round(2),
              order_revenue: order_revenue.round(2),
              booking_count: booking_count,
              order_count: order_count,
              booking_avg_check: booking_avg_check,
              order_avg_check: order_avg_check,
              platform_commission: total_commission.round(2),
              revenue_trend: revenue_trend
            }
          end
        end

        # GET /api/v1/admin/analytics/geography
        # Returns activity by city
        def geography
          period = parse_period

          cached_response(:geography, period) do
            start_date = period_start_date(period)

            # Bookings by city
            city_bookings = Booking.joins(service_point: :city)
                                   .where(created_at: start_date..Time.current)
                                   .group('cities.id', 'cities.name', 'cities.name_ru', 'cities.name_uk',
                                          'cities.latitude', 'cities.longitude')
                                   .count

            cities_data = city_bookings.map do |(city_id, name, name_ru, name_uk, lat, lng), count|
              {
                city_id: city_id,
                name: name,
                name_ru: name_ru,
                name_uk: name_uk,
                latitude: lat&.to_f,
                longitude: lng&.to_f,
                bookings_count: count,
                service_points_count: ServicePoint.joins(:city).where(cities: { id: city_id }).count
              }
            end

            # Sort by bookings count descending
            cities_data.sort_by { |c| -c[:bookings_count] }
          end
        end

        private

        # Parse period parameter (day, week, month, quarter, year)
        def parse_period
          params[:period]&.to_sym || :month
        end

        # Convert period to start date
        def period_start_date(period)
          case period
          when :day then 1.day.ago.beginning_of_day
          when :week then 1.week.ago.beginning_of_day
          when :month then 1.month.ago.beginning_of_day
          when :quarter then 3.months.ago.beginning_of_day
          when :year then 1.year.ago.beginning_of_day
          else 1.month.ago.beginning_of_day
          end
        end

        # Cache wrapper with 15 minute TTL
        def cached_response(endpoint, period)
          cache_key = "admin_analytics:#{endpoint}:#{period}:#{Date.current}"

          data = Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
            yield
          end

          render json: {
            success: true,
            data: data,
            period: period,
            cached_at: Time.current.iso8601
          }
        end

        # Active users metrics
        def active_users_metrics(period)
          start_date = period_start_date(period)
          {
            total: User.where(is_active: true).count,
            new_in_period: User.where(created_at: start_date..Time.current).count,
            active_today: User.where('last_sign_in_at >= ?', 1.day.ago).count,
            active_this_week: User.where('last_sign_in_at >= ?', 1.week.ago).count,
            active_this_month: User.where('last_sign_in_at >= ?', 1.month.ago).count
          }
        end

        # Bookings metrics
        def bookings_metrics(period)
          start_date = period_start_date(period)
          scope = Booking.where(created_at: start_date..Time.current)

          {
            total: scope.count,
            pending: scope.where(status: 'pending').count,
            confirmed: scope.where(status: %w[confirmed in_progress]).count,
            completed: scope.where(status: 'completed').count,
            cancelled: scope.where(status: %w[cancelled_by_client cancelled_by_partner]).count
          }
        end

        # Tire orders metrics
        def tire_orders_metrics(period)
          start_date = period_start_date(period)
          scope = TireOrder.where(created_at: start_date..Time.current)
                           .where.not(status: 'draft')

          {
            total: scope.count,
            total_amount: scope.sum(:total_amount).to_f.round(2),
            pending: scope.where(status: 'pending').count,
            completed: scope.where(status: 'completed').count
          }
        end

        # Count new entities in period
        def new_entity_count(model, period)
          start_date = period_start_date(period)
          model.where(created_at: start_date..Time.current).count
        end

        # Bookings trend data (daily for last 30 days)
        def bookings_trend_data(period)
          days = case period
                 when :day then 1
                 when :week then 7
                 when :month then 30
                 when :quarter then 90
                 when :year then 365
                 else 30
                 end

          start_date = days.days.ago.beginning_of_day

          # Group by day
          daily_data = Booking.where(created_at: start_date..Time.current)
                              .group("DATE(bookings.created_at)")
                              .count

          daily_completed = Booking.where(created_at: start_date..Time.current, status: 'completed')
                                   .group("DATE(bookings.created_at)")
                                   .count

          daily_cancelled = Booking.where(created_at: start_date..Time.current)
                                   .where(status: %w[cancelled_by_client cancelled_by_partner])
                                   .group("DATE(bookings.created_at)")
                                   .count

          (0...days).map do |i|
            date = start_date.to_date + i.days
            {
              date: date.iso8601,
              total: daily_data[date] || 0,
              completed: daily_completed[date] || 0,
              cancelled: daily_cancelled[date] || 0
            }
          end
        end

        # Estimate search activity from system logs or bookings
        def estimate_searches(start_date)
          # Try system logs for search events
          if defined?(SystemLog)
            search_count = SystemLog.where(created_at: start_date..Time.current)
                                    .where("action ILIKE ?", '%search%')
                                    .count
            return search_count if search_count > 0
          end

          # Fallback: estimate from bookings (typically 5-10x searches per booking)
          bookings_count = Booking.where(created_at: start_date..Time.current).count
          (bookings_count * 7.5).round
        end

        # Revenue by day for trend chart
        def booking_revenue_by_day(start_date)
          daily_revenue = Booking.where(created_at: start_date..Time.current, status: 'completed')
                                 .group("DATE(bookings.created_at)")
                                 .sum(:total_price)

          days = ((Time.current - start_date) / 1.day).ceil

          (0...days).map do |i|
            date = start_date.to_date + i.days
            {
              date: date.iso8601,
              revenue: (daily_revenue[date] || 0).to_f.round(2)
            }
          end
        end

        # Safe percentage calculation
        def safe_percent(numerator, denominator)
          return 0 if denominator.nil? || denominator.zero?
          ((numerator.to_f / denominator) * 100).round(1)
        end
      end
    end
  end
end
