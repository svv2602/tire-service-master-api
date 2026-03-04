# frozen_string_literal: true

module Api
  module V1
    # Controller for mobile device token registration.
    # Handles APNs (iOS) and FCM (Android) push notification tokens.
    #
    # Push Notification Registration Flow:
    # 1. Mobile app obtains device token from APNs/FCM
    # 2. App sends POST /api/v1/devices with token + platform
    # 3. Server stores/updates the token linked to the authenticated user
    # 4. When sending push notifications, server queries active devices for user
    # 5. On app uninstall or logout, DELETE /api/v1/devices/:id deactivates token
    class DevicesController < ApplicationController
      skip_after_action :verify_authorized
      before_action :authenticate_request
      before_action :set_device, only: [:show, :update, :destroy]

      # GET /api/v1/devices
      # List all devices for the current user
      def index
        devices = current_user.devices.active.recent

        formatted = devices.map { |d| format_device(d) }
        formatted = formatted.map { |d| apply_sparse_fieldsets(d) } if sparse_fields_requested?

        render json: {
          devices: formatted,
          total_count: current_user.devices.count,
          active_count: current_user.devices.active.count
        }
      end

      # GET /api/v1/devices/:id
      def show
        render json: format_device(@device)
      end

      # POST /api/v1/devices
      # Register a new device token or update existing one.
      # If a device with the same token already exists, it is reassigned
      # to the current user and reactivated.
      def create
        # Check if device token already exists
        existing = Device.find_by(device_token: device_params[:device_token])

        if existing
          # Reassign to current user and reactivate
          existing.update!(
            user: current_user,
            platform: device_params[:platform],
            device_name: device_params[:device_name],
            device_model: device_params[:device_model],
            os_version: device_params[:os_version],
            app_version: device_params[:app_version],
            is_active: true,
            last_used_at: Time.current
          )

          render json: {
            message: 'Device token updated',
            device: format_device(existing)
          }, status: :ok
        else
          device = current_user.devices.build(device_params)
          device.last_used_at = Time.current

          if device.save
            render json: {
              message: 'Device registered',
              device: format_device(device)
            }, status: :created
          else
            render json: { errors: device.errors.full_messages }, status: :unprocessable_entity
          end
        end
      end

      # PATCH /api/v1/devices/:id
      # Update device info (e.g. app_version after update)
      def update
        if @device.update(device_update_params)
          @device.touch_last_used!
          render json: {
            message: 'Device updated',
            device: format_device(@device)
          }
        else
          render json: { errors: @device.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/devices/:id
      # Deactivate device (soft delete — keeps record for analytics)
      def destroy
        @device.deactivate!
        render json: { message: 'Device deactivated' }
      end

      private

      def set_device
        @device = current_user.devices.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Device not found' }, status: :not_found
      end

      def device_params
        params.require(:device).permit(
          :device_token, :platform, :device_name,
          :device_model, :os_version, :app_version
        )
      end

      def device_update_params
        params.require(:device).permit(
          :device_name, :device_model, :os_version, :app_version
        )
      end

      def format_device(device)
        {
          id: device.id,
          platform: device.platform,
          device_name: device.device_name,
          device_model: device.device_model,
          os_version: device.os_version,
          app_version: device.app_version,
          is_active: device.is_active,
          last_used_at: device.last_used_at,
          created_at: device.created_at
        }
      end
    end
  end
end
