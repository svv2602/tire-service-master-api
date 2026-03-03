# frozen_string_literal: true

module Api
  module V1
    # Controller for Google Calendar integration
    class GoogleCalendarController < ApplicationController
      skip_after_action :verify_authorized
      before_action :authenticate_user!
      before_action :ensure_partner!
      before_action :set_calendar_service

      # GET /api/v1/google_calendar/status
      # Get current connection status
      def status
        setting = current_partner.google_calendar_setting

        render json: {
          connected: @service.connected?,
          calendar_id: setting&.calendar_id,
          sync_enabled: setting&.sync_enabled,
          token_expires_at: setting&.token_expires_at
        }
      end

      # GET /api/v1/google_calendar/auth_url
      # Get authorization URL for OAuth
      def auth_url
        redirect_uri = params[:redirect_uri] || "#{request.base_url}/api/v1/google_calendar/callback"
        state = SecureRandom.hex(16)

        # Store state in session or cache for verification
        Rails.cache.write("google_calendar_state:#{current_user.id}", state, expires_in: 10.minutes)

        url = @service.authorization_url(redirect_uri: redirect_uri, state: state)

        render json: { url: url, state: state }
      end

      # POST /api/v1/google_calendar/connect
      # Exchange authorization code for tokens
      def connect
        unless params[:code].present?
          return render json: { error: 'Authorization code is required' }, status: :bad_request
        end

        redirect_uri = params[:redirect_uri] || "#{request.base_url}/api/v1/google_calendar/callback"
        result = @service.exchange_code(code: params[:code], redirect_uri: redirect_uri)

        if result[:success]
          render json: { success: true, message: 'Connected successfully' }
        else
          render json: { success: false, error: result[:error] }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/google_calendar/disconnect
      # Disconnect Google Calendar
      def disconnect
        result = @service.disconnect

        if result[:success]
          render json: { success: true, message: 'Disconnected successfully' }
        else
          render json: { success: false, error: result[:error] }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/google_calendar/calendars
      # List available calendars
      def calendars
        result = @service.list_calendars

        if result[:success]
          render json: { success: true, calendars: result[:calendars] }
        else
          render json: { success: false, error: result[:error] }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/google_calendar/set_calendar
      # Set calendar to use for sync
      def set_calendar
        unless params[:calendar_id].present?
          return render json: { error: 'Calendar ID is required' }, status: :bad_request
        end

        result = @service.set_calendar(params[:calendar_id])

        if result[:success]
          render json: { success: true, message: 'Calendar set successfully' }
        else
          render json: { success: false, error: result[:error] }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/google_calendar/sync_booking
      # Sync a specific booking to calendar
      def sync_booking
        booking = find_booking(params[:booking_id])
        return unless booking

        result = @service.sync_booking(booking)

        if result[:success]
          render json: { success: true, event_id: result[:event_id] }
        else
          render json: { success: false, error: result[:error] }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/google_calendar/delete_booking
      # Remove booking from calendar
      def delete_booking
        booking = find_booking(params[:booking_id])
        return unless booking

        result = @service.delete_booking(booking)

        if result[:success]
          render json: { success: true }
        else
          render json: { success: false, error: result[:error] }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/google_calendar/sync_all
      # Sync all future bookings
      def sync_all
        result = @service.sync_all_bookings

        if result[:success]
          render json: {
            success: true,
            synced: result[:synced],
            errors: result[:errors]
          }
        else
          render json: { success: false, error: result[:error] }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/google_calendar/settings
      # Update sync settings
      def update_settings
        setting = current_partner.google_calendar_setting || current_partner.build_google_calendar_setting

        permitted_params = params.permit(:sync_enabled, :sync_confirmed_only)

        if setting.update(permitted_params)
          render json: { success: true, settings: setting.slice(:sync_enabled, :sync_confirmed_only, :calendar_id) }
        else
          render json: { success: false, error: setting.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def ensure_partner!
        return if current_user.partner? || current_user.admin?

        render json: { error: 'Only partners can access Google Calendar integration' }, status: :forbidden
      end

      def current_partner
        @current_partner ||= current_user.partner || (current_user.admin? && Partner.find_by(id: params[:partner_id]))
      end

      def set_calendar_service
        unless current_partner
          return render json: { error: 'Partner not found' }, status: :not_found
        end

        @service = GoogleCalendarService.new(current_partner)
      end

      def find_booking(booking_id)
        booking = Booking.joins(:service_point)
                        .where(service_points: { partner_id: current_partner.id })
                        .find_by(id: booking_id)

        unless booking
          render json: { error: 'Booking not found' }, status: :not_found
          return nil
        end

        booking
      end
    end
  end
end
