# frozen_string_literal: true

module Api
  module V1
    class PaymentHistoryController < ApiController
      before_action :authenticate_request
      before_action :set_payment, only: [:show, :receipt, :refund_request]

      # GET /api/v1/payments
      # List payment history for current user (admins see all)
      def index
        payments = base_scope.recent

        # Apply filters
        payments = payments.by_type(params[:type]) if params[:type].present?
        payments = payments.by_status(params[:status]) if params[:status].present?

        result = paginate(payments)

        render json: {
          data: result[:data].map { |p| format_payment(p) },
          meta: {
            currentPage: result[:pagination][:current_page],
            totalPages: result[:pagination][:total_pages],
            totalCount: result[:pagination][:total_count],
            perPage: result[:pagination][:per_page]
          }
        }
      end

      # GET /api/v1/payments/:id
      # Show detailed payment info
      def show
        render json: format_payment_detail(@payment)
      end

      # GET /api/v1/payments/:id/receipt
      # Get receipt URL for a payment
      def receipt
        if @payment.receipt_url.present?
          render json: { receiptUrl: @payment.receipt_url }
        else
          render json: { receiptUrl: nil, message: 'Receipt not available' }
        end
      end

      # POST /api/v1/payments/:payment_id/refund_request
      # Client-initiated refund request
      def refund_request
        @payment = base_scope.find(params[:payment_id])

        unless @payment.status.in?(%w[success partially_refunded])
          return render json: { error: 'Refund not available for this payment status' }, status: :unprocessable_entity
        end

        refund = @payment.refund_requests.build(
          user: current_user,
          amount: params[:amount],
          reason: params[:reason],
          reason_category: params[:reason_category],
          is_full_refund: params[:is_full_refund] || false,
          status: 'pending'
        )

        if refund.save
          render json: {
            success: true,
            refundId: refund.id
          }, status: :created
        else
          render json: {
            success: false,
            errors: refund.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      private

      def base_scope
        if current_user.admin?
          Payment.all
        else
          Payment.by_user(current_user.id)
        end
      end

      def set_payment
        @payment = base_scope.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Payment not found' }, status: :not_found
      end

      def format_payment(payment)
        {
          id: payment.id,
          paymentId: payment.payment_id,
          provider: payment.provider,
          type: payment.payment_type,
          entityId: payment.entity_id,
          amount: payment.amount.to_f,
          currency: payment.currency,
          status: payment.status,
          description: payment.description,
          paidAt: payment.paid_at&.iso8601,
          refundedAt: payment.refunded_at&.iso8601,
          refundAmount: payment.refund_amount&.to_f,
          receiptUrl: payment.receipt_url,
          createdAt: payment.created_at.iso8601
        }
      end

      def format_payment_detail(payment)
        detail = format_payment(payment)
        detail[:providerPaymentId] = payment.provider_payment_id

        # Include related entity info
        entity = payment.related_entity
        if payment.booking? && entity
          detail[:booking] = {
            id: entity.id,
            status: entity.status,
            servicePointName: entity.service_point&.name,
            date: entity.booking_date&.to_s
          }
        elsif payment.order? && entity
          detail[:order] = {
            id: entity.id,
            status: entity.status,
            items: entity.respond_to?(:tire_order_items) ? entity.tire_order_items.map { |item|
              {
                name: item.supplier_tire_product&.name || 'Unknown',
                quantity: item.quantity,
                price: item.price_at_order.to_f
              }
            } : []
          }
        end

        # Include refund records
        detail[:refunds] = payment.refund_requests.recent.map do |refund|
          {
            id: refund.id,
            amount: refund.amount.to_f,
            reason: refund.reason,
            status: refund.status,
            requestedAt: refund.created_at.iso8601,
            processedAt: refund.processed_at&.iso8601
          }
        end

        detail
      end
    end
  end
end
