# frozen_string_literal: true

module Api
  module V1
    # Controller for delivery tracking operations
    class DeliveryController < ApplicationController
      before_action :authenticate_user!, except: [:track]

      # GET /api/v1/delivery/track/:ttn
      # Track shipment by TTN (available without auth for public tracking)
      def track
        ttn = params[:ttn]

        unless valid_ttn?(ttn)
          return render json: { success: false, error: 'Invalid TTN format' }, status: :bad_request
        end

        tracking = nova_poshta.track_shipment(ttn)

        if tracking
          render json: {
            success: true,
            tracking: tracking.except(:raw_data),
            delivery_status: calculate_delivery_status(tracking[:status_code])
          }
        else
          render json: { success: false, error: 'Tracking information not found' }, status: :not_found
        end
      rescue NovaPoshtaService::ValidationError => e
        render json: { success: false, error: e.message }, status: :unprocessable_entity
      rescue NovaPoshtaService::ApiError => e
        Rails.logger.error("Nova Poshta API error: #{e.message}")
        render json: { success: false, error: 'Delivery tracking service unavailable' }, status: :service_unavailable
      end

      # GET /api/v1/delivery/cities
      # Search cities for autocomplete
      def cities
        query = params[:query]

        if query.blank? || query.length < 2
          return render json: { success: false, error: 'Query must be at least 2 characters' }, status: :bad_request
        end

        cities = nova_poshta.search_cities(query, limit: params[:limit] || 20)

        render json: { success: true, cities: cities }
      rescue NovaPoshtaService::ApiError => e
        Rails.logger.error("Nova Poshta API error: #{e.message}")
        render json: { success: false, error: 'Service unavailable' }, status: :service_unavailable
      end

      # GET /api/v1/delivery/warehouses
      # Get warehouses in a city
      def warehouses
        city_ref = params[:city_ref]

        if city_ref.blank?
          return render json: { success: false, error: 'city_ref is required' }, status: :bad_request
        end

        warehouses = nova_poshta.get_warehouses(city_ref, limit: params[:limit] || 100)

        render json: { success: true, warehouses: warehouses }
      rescue NovaPoshtaService::ApiError => e
        Rails.logger.error("Nova Poshta API error: #{e.message}")
        render json: { success: false, error: 'Service unavailable' }, status: :service_unavailable
      end

      # POST /api/v1/delivery/calculate
      # Calculate delivery cost
      def calculate
        required_params = %i[city_sender city_recipient weight cost]
        missing = required_params.select { |p| params[p].blank? }

        if missing.any?
          return render json: {
            success: false,
            error: "Missing required parameters: #{missing.join(', ')}"
          }, status: :bad_request
        end

        cost = nova_poshta.calculate_delivery_cost(
          city_sender: params[:city_sender],
          city_recipient: params[:city_recipient],
          weight: params[:weight],
          cost: params[:cost],
          service_type: params[:service_type] || 'WarehouseWarehouse'
        )

        if cost
          render json: { success: true, delivery_cost: cost }
        else
          render json: { success: false, error: 'Could not calculate delivery cost' }, status: :unprocessable_entity
        end
      rescue NovaPoshtaService::ApiError => e
        Rails.logger.error("Nova Poshta API error: #{e.message}")
        render json: { success: false, error: 'Service unavailable' }, status: :service_unavailable
      end

      # GET /api/v1/delivery/order/:order_id/tracking
      # Get tracking for a specific order
      def order_tracking
        order = find_order

        unless order
          return render json: { success: false, error: 'Order not found' }, status: :not_found
        end

        unless order.ttn.present?
          return render json: {
            success: true,
            tracking: nil,
            message: 'Tracking number not yet assigned'
          }
        end

        tracking = nova_poshta.track_shipment(order.ttn)

        if tracking
          # Update order status if changed
          update_order_delivery_status(order, tracking)

          render json: {
            success: true,
            order_id: order.id,
            ttn: order.ttn,
            tracking: tracking.except(:raw_data),
            delivery_status: calculate_delivery_status(tracking[:status_code])
          }
        else
          render json: {
            success: true,
            order_id: order.id,
            ttn: order.ttn,
            tracking: nil,
            message: 'Tracking information not available yet'
          }
        end
      rescue NovaPoshtaService::ApiError => e
        Rails.logger.error("Nova Poshta API error: #{e.message}")
        render json: { success: false, error: 'Delivery tracking service unavailable' }, status: :service_unavailable
      end

      private

      def nova_poshta
        @nova_poshta ||= NovaPoshtaService.new
      end

      def valid_ttn?(ttn)
        return false if ttn.blank?

        # TTN should be 14 digits
        cleaned = ttn.to_s.gsub(/\D/, '')
        cleaned.length == 14
      end

      def calculate_delivery_status(status_code)
        if nova_poshta.delivery_completed?(status_code)
          'delivered'
        elsif nova_poshta.delivery_failed?(status_code)
          'failed'
        elsif nova_poshta.in_transit?(status_code)
          'in_transit'
        else
          'pending'
        end
      end

      def find_order
        order_id = params[:order_id]

        # Try to find in regular orders or tire orders
        order = Order.find_by(id: order_id)
        order ||= TireOrder.find_by(id: order_id)

        # Authorize access
        return nil unless order

        if current_user.admin?
          order
        elsif order.is_a?(Order) && current_user.partner? && order.partner_id == current_user.partner&.id
          order
        elsif order.is_a?(TireOrder) && order.client_id == current_user.client&.id
          order
        else
          nil
        end
      end

      def update_order_delivery_status(order, tracking)
        return unless order.respond_to?(:ttn_status)

        status_code = tracking[:status_code]
        current_status = order.ttn_status

        # Only update if status changed
        return if current_status == tracking[:status]

        order.update(
          ttn_status: tracking[:status],
          ttn_status_kod: status_code,
          metadata: (order.metadata || {}).merge(
            last_tracking_update: Time.current.iso8601,
            tracking_history: ((order.metadata || {})['tracking_history'] || []) + [{
              status: tracking[:status],
              status_code: status_code,
              timestamp: Time.current.iso8601
            }]
          )
        )

        # Mark as delivered if completed
        if nova_poshta.delivery_completed?(status_code) && order.respond_to?(:mark_as_delivered!)
          order.update(delivered_at: Time.current) unless order.delivered_at.present?
        end
      end
    end
  end
end
