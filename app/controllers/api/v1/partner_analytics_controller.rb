# frozen_string_literal: true

module Api
  module V1
    class PartnerAnalyticsController < ApiController
      skip_after_action :verify_authorized
      before_action :authenticate_user!
      before_action :ensure_partner_access
      before_action :set_partner

      # GET /api/v1/partners/:partner_id/analytics/overview
      def overview
        period = params[:period] || 'month'
        period_range = calculate_period_range(period)
        comparison_range = calculate_comparison_range(period)

        current_stats = calculate_stats(period_range)
        previous_stats = calculate_stats(comparison_range)

        render json: {
          period: period,
          current_period: {
            start_date: period_range.first.strftime('%Y-%m-%d'),
            end_date: period_range.last.strftime('%Y-%m-%d'),
            stats: current_stats
          },
          previous_period: {
            start_date: comparison_range.first.strftime('%Y-%m-%d'),
            end_date: comparison_range.last.strftime('%Y-%m-%d'),
            stats: previous_stats
          },
          comparison: calculate_comparison(current_stats, previous_stats)
        }
      end

      # GET /api/v1/partners/:partner_id/analytics/revenue
      def revenue
        period = params[:period] || 'month'
        group_by = params[:group_by] || 'day'
        period_range = calculate_period_range(period)

        revenue_data = get_revenue_data(period_range, group_by)
        comparison_range = calculate_comparison_range(period)
        comparison_data = get_revenue_data(comparison_range, group_by)

        render json: {
          period: period,
          group_by: group_by,
          current: revenue_data,
          previous: comparison_data,
          summary: {
            current_total: revenue_data[:values].sum,
            previous_total: comparison_data[:values].sum,
            change_percent: calculate_percent_change(
              comparison_data[:values].sum,
              revenue_data[:values].sum
            )
          }
        }
      end

      # GET /api/v1/partners/:partner_id/analytics/bookings
      def bookings
        period = params[:period] || 'month'
        group_by = params[:group_by] || 'day'
        period_range = calculate_period_range(period)

        bookings_data = get_bookings_data(period_range, group_by)
        comparison_range = calculate_comparison_range(period)
        comparison_data = get_bookings_data(comparison_range, group_by)

        render json: {
          period: period,
          group_by: group_by,
          current: bookings_data,
          previous: comparison_data,
          summary: calculate_bookings_summary(bookings_data, comparison_data)
        }
      end

      # GET /api/v1/partners/:partner_id/analytics/top_services
      def top_services
        period = params[:period] || 'month'
        limit = (params[:limit] || 10).to_i
        period_range = calculate_period_range(period)

        services = get_top_services_data(period_range, limit)

        render json: {
          period: period,
          services: services
        }
      end

      # GET /api/v1/partners/:partner_id/analytics/service_points
      def service_points
        period = params[:period] || 'month'
        period_range = calculate_period_range(period)

        service_points_stats = @partner.service_points.includes(:city).map do |sp|
          bookings = sp.bookings.where(booking_date: period_range)
          orders = sp.orders.where(created_at: period_range.first.beginning_of_day..period_range.last.end_of_day)

          {
            id: sp.id,
            name: sp.name,
            city: sp.city&.name,
            bookings_count: bookings.count,
            completed_bookings: bookings.where(status: 'completed').count,
            cancelled_bookings: bookings.where(status: %w[cancelled_by_client cancelled_by_partner]).count,
            orders_count: orders.count,
            revenue: bookings.where(status: 'completed').sum(:total_price).to_f,
            average_rating: sp.reviews.average(:rating)&.round(2) || 0
          }
        end

        render json: {
          period: period,
          service_points: service_points_stats.sort_by { |sp| -sp[:revenue] }
        }
      end

      # GET /api/v1/partners/:partner_id/analytics/export
      def export
        period = params[:period] || 'month'
        format = params[:format] || 'csv'
        period_range = calculate_period_range(period)

        case format
        when 'csv'
          export_csv(period_range)
        when 'xlsx'
          export_xlsx(period_range)
        else
          render json: { error: 'Unsupported format. Use csv or xlsx' }, status: :bad_request
        end
      end

      private

      def ensure_partner_access
        unless current_user&.partner? || current_user&.admin?
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

      def calculate_period_range(period)
        case period
        when 'week'
          (Date.current - 7.days)..Date.current
        when 'month'
          (Date.current - 30.days)..Date.current
        when 'quarter'
          (Date.current - 90.days)..Date.current
        when 'year'
          (Date.current - 365.days)..Date.current
        else
          (Date.current - 30.days)..Date.current
        end
      end

      def calculate_comparison_range(period)
        period_length = case period
                        when 'week' then 7.days
                        when 'month' then 30.days
                        when 'quarter' then 90.days
                        when 'year' then 365.days
                        else 30.days
                        end

        (Date.current - (period_length * 2))...(Date.current - period_length)
      end

      def calculate_stats(period_range)
        bookings = partner_bookings.where(booking_date: period_range)
        orders = partner_orders.where(created_at: period_range.first.beginning_of_day..period_range.last.end_of_day)

        {
          total_bookings: bookings.count,
          completed_bookings: bookings.where(status: 'completed').count,
          cancelled_bookings: bookings.where(status: %w[cancelled_by_client cancelled_by_partner]).count,
          pending_bookings: bookings.where(status: 'pending').count,
          total_orders: orders.count,
          delivered_orders: orders.where(status: 'delivered').count,
          revenue_bookings: bookings.where(status: 'completed').sum(:total_price).to_f,
          revenue_orders: orders.where(status: 'delivered').sum(:total_amount).to_f,
          total_revenue: bookings.where(status: 'completed').sum(:total_price).to_f +
                         orders.where(status: 'delivered').sum(:total_amount).to_f
        }
      end

      def calculate_comparison(current, previous)
        {
          bookings_change: calculate_percent_change(previous[:total_bookings], current[:total_bookings]),
          orders_change: calculate_percent_change(previous[:total_orders], current[:total_orders]),
          revenue_change: calculate_percent_change(previous[:total_revenue], current[:total_revenue]),
          completion_rate_current: current[:total_bookings] > 0 ?
            (current[:completed_bookings].to_f / current[:total_bookings] * 100).round(1) : 0,
          completion_rate_previous: previous[:total_bookings] > 0 ?
            (previous[:completed_bookings].to_f / previous[:total_bookings] * 100).round(1) : 0
        }
      end

      def calculate_percent_change(old_value, new_value)
        return 0 if old_value.nil? || old_value.zero?
        ((new_value.to_f - old_value.to_f) / old_value.to_f * 100).round(1)
      end

      def get_revenue_data(period_range, group_by)
        date_format = case group_by
                      when 'day' then '%Y-%m-%d'
                      when 'week' then '%Y-W%V'
                      when 'month' then '%Y-%m'
                      else '%Y-%m-%d'
                      end

        sql_format = case group_by
                     when 'day' then "DATE_TRUNC('day', bookings.booking_date)"
                     when 'week' then "DATE_TRUNC('week', bookings.booking_date)"
                     when 'month' then "DATE_TRUNC('month', bookings.booking_date)"
                     else "DATE_TRUNC('day', bookings.booking_date)"
                     end

        revenue_by_period = partner_bookings
                              .where(status: 'completed')
                              .where(booking_date: period_range)
                              .group(Arel.sql(sql_format))
                              .sum(:total_price)

        labels = generate_date_labels(period_range, group_by)
        values = labels.map { |label| revenue_by_period[label.to_date]&.to_f || 0 }

        { labels: labels.map { |l| l.strftime(date_format) }, values: values }
      end

      def get_bookings_data(period_range, group_by)
        sql_format = case group_by
                     when 'day' then "DATE_TRUNC('day', bookings.booking_date)"
                     when 'week' then "DATE_TRUNC('week', bookings.booking_date)"
                     when 'month' then "DATE_TRUNC('month', bookings.booking_date)"
                     else "DATE_TRUNC('day', bookings.booking_date)"
                     end

        all_bookings = partner_bookings.where(booking_date: period_range)
        completed = all_bookings.where(status: 'completed').group(Arel.sql(sql_format)).count
        cancelled = all_bookings.where(status: %w[cancelled_by_client cancelled_by_partner]).group(Arel.sql(sql_format)).count
        pending = all_bookings.where(status: 'pending').group(Arel.sql(sql_format)).count

        labels = generate_date_labels(period_range, group_by)

        {
          labels: labels.map { |l| l.strftime('%Y-%m-%d') },
          completed: labels.map { |l| completed[l.to_date] || 0 },
          cancelled: labels.map { |l| cancelled[l.to_date] || 0 },
          pending: labels.map { |l| pending[l.to_date] || 0 }
        }
      end

      def calculate_bookings_summary(current, previous)
        current_total = current[:completed].sum + current[:cancelled].sum + current[:pending].sum
        previous_total = previous[:completed].sum + previous[:cancelled].sum + previous[:pending].sum

        {
          current_total: current_total,
          previous_total: previous_total,
          change_percent: calculate_percent_change(previous_total, current_total),
          current_completed: current[:completed].sum,
          current_cancelled: current[:cancelled].sum
        }
      end

      def get_top_services_data(period_range, limit)
        Service.joins(booking_services: :booking)
               .joins('INNER JOIN service_points ON bookings.service_point_id = service_points.id')
               .where(service_points: { partner_id: @partner.id })
               .where(bookings: { booking_date: period_range })
               .group('services.id, services.name')
               .order(Arel.sql('COUNT(booking_services.id) DESC'))
               .limit(limit)
               .pluck('services.id', 'services.name', Arel.sql('COUNT(booking_services.id)'), Arel.sql('SUM(booking_services.price)'))
               .map do |id, name, count, revenue|
                 {
                   id: id,
                   name: name,
                   bookings_count: count,
                   revenue: revenue.to_f
                 }
               end
      end

      def generate_date_labels(period_range, group_by)
        labels = []
        current = period_range.first

        while current <= period_range.last
          labels << current
          current = case group_by
                    when 'day' then current + 1.day
                    when 'week' then current + 1.week
                    when 'month' then current + 1.month
                    else current + 1.day
                    end
        end

        labels
      end

      def partner_bookings
        Booking.joins(:service_point).where(service_points: { partner_id: @partner.id })
      end

      def partner_orders
        Order.joins(:service_point).where(service_points: { partner_id: @partner.id })
      end

      def export_csv(period_range)
        require 'csv'

        csv_data = CSV.generate(headers: true) do |csv|
          csv << ['Дата', 'Тип', 'Сервисная точка', 'Услуги', 'Сумма', 'Статус']

          # Export bookings
          partner_bookings.where(booking_date: period_range).includes(:service_point, :services).each do |booking|
            csv << [
              booking.booking_date.strftime('%Y-%m-%d'),
              'Бронирование',
              booking.service_point.name,
              booking.services.map(&:name).join(', '),
              booking.total_price,
              booking.status
            ]
          end

          # Export orders
          partner_orders.where(created_at: period_range.first.beginning_of_day..period_range.last.end_of_day)
                        .includes(:service_point).each do |order|
            csv << [
              order.created_at.strftime('%Y-%m-%d'),
              'Заказ',
              order.service_point.name,
              "#{order.total_quantity} товаров",
              order.total_amount,
              order.status
            ]
          end
        end

        send_data csv_data,
                  filename: "analytics_#{@partner.company_name}_#{Date.current.strftime('%Y%m%d')}.csv",
                  type: 'text/csv',
                  disposition: 'attachment'
      end

      def export_xlsx(period_range)
        # Placeholder for XLSX export - requires additional gem like caxlsx
        render json: { error: 'XLSX export not implemented yet' }, status: :not_implemented
      end
    end
  end
end
