# Payments Controller for handling LiqPay integration
class Api::V1::PaymentsController < Api::V1::BaseController
  skip_before_action :authenticate_request!, only: [:liqpay_callback]
  skip_before_action :verify_authenticity_token, only: [:liqpay_callback], if: -> { request.format.json? }

  # POST /api/v1/payments/booking/:booking_id
  # Create payment for booking
  def create_booking_payment
    booking = Booking.find(params[:booking_id])

    # Authorize access
    unless can_pay_for_booking?(booking)
      return render json: { error: 'Unauthorized' }, status: :forbidden
    end

    # Calculate amount (from booking services or fixed amount)
    amount = calculate_booking_amount(booking)

    if amount <= 0
      return render json: { error: 'Invalid payment amount' }, status: :unprocessable_entity
    end

    # Create LiqPay payment
    liqpay = LiqpayService.new
    payment_data = liqpay.create_booking_payment(
      booking: booking,
      amount: amount,
      description: params[:description]
    )

    # Update booking payment status to pending
    booking.update!(payment_status_id: PaymentStatus.pending_id)

    render json: {
      success: true,
      payment: {
        checkout_url: payment_data[:checkout_url],
        data: payment_data[:data],
        signature: payment_data[:signature],
        order_id: payment_data[:order_id],
        amount: payment_data[:amount],
        sandbox: payment_data[:sandbox]
      }
    }
  rescue LiqpayService::ConfigurationError => e
    Rails.logger.error "[Payments] LiqPay configuration error: #{e.message}"
    render json: { error: 'Payment service not configured' }, status: :service_unavailable
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Booking not found' }, status: :not_found
  rescue StandardError => e
    Rails.logger.error "[Payments] Error creating payment: #{e.message}"
    render json: { error: 'Failed to create payment' }, status: :internal_server_error
  end

  # POST /api/v1/payments/order/:order_id
  # Create payment for tire order
  def create_order_payment
    order = TireOrder.find(params[:order_id])

    # Authorize access
    unless can_pay_for_order?(order)
      return render json: { error: 'Unauthorized' }, status: :forbidden
    end

    amount = order.total_amount || params[:amount].to_f

    if amount <= 0
      return render json: { error: 'Invalid payment amount' }, status: :unprocessable_entity
    end

    # Create LiqPay payment
    liqpay = LiqpayService.new
    payment_data = liqpay.create_order_payment(
      order: order,
      amount: amount,
      description: params[:description]
    )

    # Update order payment status
    order.update!(payment_status: 'pending')

    render json: {
      success: true,
      payment: {
        checkout_url: payment_data[:checkout_url],
        data: payment_data[:data],
        signature: payment_data[:signature],
        order_id: payment_data[:order_id],
        amount: payment_data[:amount],
        sandbox: payment_data[:sandbox]
      }
    }
  rescue LiqpayService::ConfigurationError => e
    Rails.logger.error "[Payments] LiqPay configuration error: #{e.message}"
    render json: { error: 'Payment service not configured' }, status: :service_unavailable
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Order not found' }, status: :not_found
  rescue StandardError => e
    Rails.logger.error "[Payments] Error creating order payment: #{e.message}"
    render json: { error: 'Failed to create payment' }, status: :internal_server_error
  end

  # POST /api/v1/payments/liqpay/callback
  # Handle LiqPay callback
  def liqpay_callback
    data = params[:data]
    signature = params[:signature]

    unless data.present? && signature.present?
      Rails.logger.warn '[Payments] Invalid callback: missing data or signature'
      return render json: { error: 'Invalid callback data' }, status: :bad_request
    end

    liqpay = LiqpayService.new
    result = liqpay.process_callback(data: data, signature: signature)

    Rails.logger.info "[Payments] Callback processed: status=#{result[:status]}, order_id=#{result[:order_id]}"

    render json: { success: true, status: result[:status] }
  rescue LiqpayService::PaymentError => e
    Rails.logger.error "[Payments] Payment error: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  rescue LiqpayService::ConfigurationError => e
    Rails.logger.error "[Payments] Configuration error: #{e.message}"
    render json: { error: 'Payment service not configured' }, status: :service_unavailable
  rescue StandardError => e
    Rails.logger.error "[Payments] Callback error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    render json: { error: 'Callback processing failed' }, status: :internal_server_error
  end

  # GET /api/v1/payments/status/:order_id
  # Check payment status
  def status
    order_id = params[:order_id]

    liqpay = LiqpayService.new
    result = liqpay.check_payment_status(order_id)

    render json: {
      success: true,
      status: result['status'],
      amount: result['amount'],
      currency: result['currency'],
      description: result['description']
    }
  rescue LiqpayService::ConfigurationError => e
    render json: { error: 'Payment service not configured' }, status: :service_unavailable
  rescue StandardError => e
    Rails.logger.error "[Payments] Status check error: #{e.message}"
    render json: { error: 'Failed to check status' }, status: :internal_server_error
  end

  # POST /api/v1/payments/refund
  # Refund payment (admin only)
  def refund
    unless current_user&.admin?
      return render json: { error: 'Admin access required' }, status: :forbidden
    end

    order_id = params[:order_id]
    amount = params[:amount].to_f

    if order_id.blank? || amount <= 0
      return render json: { error: 'Invalid refund parameters' }, status: :unprocessable_entity
    end

    liqpay = LiqpayService.new
    result = liqpay.refund_payment(order_id: order_id, amount: amount)

    if result['status'].in?(%w[reversed success])
      # Update corresponding Payment record
      payment = Payment.find_by(payment_id: order_id)
      if payment
        refund_amount = amount < payment.amount ? amount : payment.amount
        new_status = refund_amount < payment.amount ? 'partially_refunded' : 'refunded'
        payment.update!(
          status: new_status,
          refunded_at: Time.current,
          refund_amount: refund_amount
        )
      end

      render json: { success: true, status: result['status'] }
    else
      render json: {
        success: false,
        status: result['status'],
        error: result['err_description'] || 'Refund failed'
      }, status: :unprocessable_entity
    end
  rescue LiqpayService::ConfigurationError => e
    render json: { error: 'Payment service not configured' }, status: :service_unavailable
  rescue StandardError => e
    Rails.logger.error "[Payments] Refund error: #{e.message}"
    render json: { error: 'Failed to process refund' }, status: :internal_server_error
  end

  private

  def can_pay_for_booking?(booking)
    return true if current_user&.admin?
    return true if booking.client&.user_id == current_user&.id
    false
  end

  def can_pay_for_order?(order)
    return true if current_user&.admin?
    return true if order.client&.user_id == current_user&.id
    false
  end

  def calculate_booking_amount(booking)
    # Use booking's total price or calculate from services
    return booking.total_price if booking.respond_to?(:total_price) && booking.total_price.present?

    # Sum up all selected services
    if booking.respond_to?(:booking_services)
      booking.booking_services.sum { |bs| bs.service&.price.to_f }
    else
      0
    end
  end
end
