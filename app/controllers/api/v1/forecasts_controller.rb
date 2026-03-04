# frozen_string_literal: true

module Api
  module V1
    class ForecastsController < ApiController
      skip_after_action :verify_authorized
      before_action :authenticate_user!
      before_action :ensure_partner_access
      before_action :set_partner
      before_action :set_service_point, only: [:service_point_forecast]

      # GET /api/v1/partners/:partner_id/forecasts
      # Returns forecast for all partner's service points combined
      def index
        result = ForecastService.new(@partner, forecast_options).call

        if result.success?
          render json: {
            success: true,
            partner_id: @partner.id,
            **result.data
          }
        else
          render json: { success: false, error: result.error }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/partners/:partner_id/forecasts/weekly
      # Returns detailed weekly forecast with hourly breakdown
      def weekly
        result = ForecastService.new(@partner, forecast_options.merge(forecast_days: 7)).call

        if result.success?
          weekly_data = build_weekly_view(result.data[:forecast])

          render json: {
            success: true,
            partner_id: @partner.id,
            week_start: Date.current.beginning_of_week.strftime('%Y-%m-%d'),
            week_end: (Date.current.beginning_of_week + 6.days).strftime('%Y-%m-%d'),
            days: weekly_data,
            recommendations: result.data[:recommendations],
            peak_days: result.data[:peak_days]
          }
        else
          render json: { success: false, error: result.error }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/partners/:partner_id/forecasts/recommendations
      # Returns only recommendations
      def recommendations
        result = ForecastService.new(@partner, forecast_options).call

        if result.success?
          render json: {
            success: true,
            partner_id: @partner.id,
            recommendations: result.data[:recommendations],
            historical_summary: result.data[:historical_summary]
          }
        else
          render json: { success: false, error: result.error }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/partners/:partner_id/forecasts/service_point/:service_point_id
      # Returns forecast for specific service point
      def service_point_forecast
        result = ForecastService.new(@service_point, forecast_options).call

        if result.success?
          render json: {
            success: true,
            service_point_id: @service_point.id,
            service_point_name: @service_point.name,
            **result.data
          }
        else
          render json: { success: false, error: result.error }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/partners/:partner_id/forecasts/compare
      # Compare forecasts across service points
      def compare
        service_points_forecasts = @partner.service_points.map do |sp|
          result = ForecastService.new(sp, forecast_options.merge(forecast_days: 7)).call
          next nil unless result.success?

          {
            service_point_id: sp.id,
            service_point_name: sp.name,
            city: sp.city&.name,
            forecast: result.data[:forecast],
            peak_days: result.data[:peak_days].select { |d| d[:is_peak] }.map { |d| d[:day_of_week] },
            trend: result.data[:historical_summary][:trends]
          }
        end.compact

        render json: {
          success: true,
          partner_id: @partner.id,
          service_points: service_points_forecasts,
          summary: build_comparison_summary(service_points_forecasts)
        }
      end

      # POST /api/v1/partners/:partner_id/forecasts/notify_peak
      # Subscribe to peak day notifications
      def notify_peak
        # Enable peak day notifications for the partner
        threshold = params[:threshold]&.to_f || 1.5

        # Store preference (could be in a settings table)
        @partner.update(
          peak_notification_enabled: true,
          peak_notification_threshold: threshold
        ) if @partner.respond_to?(:peak_notification_enabled=)

        # Schedule notification job
        ForecastNotificationJob.perform_later(@partner.id) if defined?(ForecastNotificationJob)

        render json: {
          success: true,
          message: 'Peak day notifications enabled',
          threshold: threshold
        }
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

      def set_service_point
        @service_point = @partner.service_points.find(params[:service_point_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Service point not found' }, status: :not_found
      end

      def forecast_options
        {
          lookback_weeks: (params[:lookback_weeks] || 8).to_i,
          forecast_days: (params[:forecast_days] || 7).to_i,
          include_seasonality: params[:include_seasonality] != 'false',
          include_ai: params[:include_ai] != 'false'
        }
      end

      def build_weekly_view(forecast)
        forecast.map do |day|
          day.merge(
            hourly_distribution: estimate_hourly_distribution(day[:predicted_bookings])
          )
        end
      end

      def estimate_hourly_distribution(total_bookings)
        # Typical distribution pattern for tire service
        # Peak hours: 10-12 and 14-16
        distribution = {
          '08:00' => 0.05,
          '09:00' => 0.08,
          '10:00' => 0.12,
          '11:00' => 0.12,
          '12:00' => 0.08,
          '13:00' => 0.08,
          '14:00' => 0.12,
          '15:00' => 0.12,
          '16:00' => 0.10,
          '17:00' => 0.08,
          '18:00' => 0.05
        }

        distribution.transform_values { |ratio| (total_bookings * ratio).round }
      end

      def build_comparison_summary(forecasts)
        return {} if forecasts.empty?

        total_predicted = forecasts.sum { |f| f[:forecast].sum { |d| d[:predicted_bookings] } }
        busiest_sp = forecasts.max_by { |f| f[:forecast].sum { |d| d[:predicted_bookings] } }

        {
          total_predicted_bookings: total_predicted,
          average_per_service_point: (total_predicted.to_f / forecasts.count).round(1),
          busiest_service_point: busiest_sp ? {
            id: busiest_sp[:service_point_id],
            name: busiest_sp[:service_point_name]
          } : nil,
          service_points_count: forecasts.count
        }
      end
    end
  end
end
