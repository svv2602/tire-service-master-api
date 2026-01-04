# frozen_string_literal: true

module Api
  module V1
    # Controller for QR code generation and verification
    class QrCodesController < ApplicationController
      before_action :authenticate_user!
      before_action :set_order, only: [:generate, :show]
      before_action :authorize_order_access!, only: [:generate, :show]

      # GET /api/v1/qr_codes/:order_type/:order_id
      # Get QR code for an order
      def show
        # Generate token if not exists
        QrCodeService.generate_token(@order) unless @order.qr_code_token

        render json: {
          qr_code_token: @order.qr_code_token,
          qr_code_svg: QrCodeService.generate_svg(@order),
          qr_code_png_base64: QrCodeService.generate_png_base64(@order),
          order_type: params[:order_type],
          order_id: @order.id,
          order_number: order_number,
          status: @order.status,
          can_scan: order_ready?
        }
      end

      # POST /api/v1/qr_codes/:order_type/:order_id/generate
      # Generate new QR code (regenerate)
      def generate
        token = QrCodeService.generate_token(@order)

        render json: {
          qr_code_token: token,
          qr_code_svg: QrCodeService.generate_svg(@order),
          message: 'QR code generated successfully'
        }
      end

      # POST /api/v1/qr_codes/scan
      # Scan and verify QR code
      def scan
        token = params[:token]

        unless token.present?
          return render json: { error: 'Token is required' }, status: :bad_request
        end

        result = QrCodeService.verify_and_process(token, current_user)

        render json: {
          success: true,
          message: 'Order marked as delivered',
          data: result
        }
      rescue QrCodeService::InvalidTokenError => e
        render json: { error: e.message, error_code: 'invalid_token' }, status: :not_found
      rescue QrCodeService::OrderNotReadyError => e
        render json: { error: e.message, error_code: 'not_ready' }, status: :unprocessable_entity
      rescue QrCodeService::AlreadyScannedError => e
        render json: { error: e.message, error_code: 'already_scanned' }, status: :conflict
      end

      # GET /api/v1/qr_codes/lookup
      # Lookup order by QR token without processing
      def lookup
        token = params[:token]

        unless token.present?
          return render json: { error: 'Token is required' }, status: :bad_request
        end

        order = find_order_by_token(token)

        unless order
          return render json: { error: 'Order not found' }, status: :not_found
        end

        render json: {
          order_type: order.class.name.underscore,
          order_id: order.id,
          order_number: order.respond_to?(:ttn) ? order.ttn : order.order_number,
          customer_name: order.customer_name,
          customer_phone: order.customer_phone,
          status: order.status,
          total_amount: order.total_amount,
          already_scanned: order.qr_scanned_at.present?,
          scanned_at: order.qr_scanned_at,
          can_deliver: order_can_deliver?(order)
        }
      end

      private

      def set_order
        @order = case params[:order_type]
                 when 'order', 'orders'
                   Order.find(params[:order_id])
                 when 'tire_order', 'tire_orders'
                   TireOrder.find(params[:order_id])
                 else
                   raise ActiveRecord::RecordNotFound, 'Invalid order type'
                 end
      end

      def authorize_order_access!
        # Check if user has access to this order's service point
        return if current_user.admin?

        service_point = @order.service_point
        partner = service_point&.partner

        unless partner && (partner.user_id == current_user.id ||
                          current_user.operator&.service_points&.include?(service_point) ||
                          current_user.manager&.partner_id == partner.id)
          render json: { error: 'Access denied' }, status: :forbidden
        end
      end

      def order_number
        @order.respond_to?(:ttn) ? @order.ttn : @order.order_number
      end

      def order_ready?
        case @order
        when Order
          @order.status_ready?
        when TireOrder
          %w[ready ready_for_pickup].include?(@order.status)
        else
          false
        end
      end

      def find_order_by_token(token)
        Order.find_by(qr_code_token: token) || TireOrder.find_by(qr_code_token: token)
      end

      def order_can_deliver?(order)
        case order
        when Order
          order.can_mark_as_delivered?
        when TireOrder
          %w[ready ready_for_pickup].include?(order.status)
        else
          false
        end
      end
    end
  end
end
