# frozen_string_literal: true

# Automatically initiates a refund via LiqPay when a paid booking is cancelled.
class PaymentAutoRefundJob < ApplicationJob
  queue_as :default

  # Only retry transient errors (network issues, etc.)
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # @param booking_id [Integer] ID of the cancelled booking
  def perform(booking_id)
    booking = Booking.find_by(id: booking_id)
    return unless booking
    return unless booking.cancelled_status?

    # Check if booking was paid
    return unless booking.payment_status_id == PaymentStatus.paid_id

    # Find the related Payment record
    payment = Payment.find_by(payment_type: 'booking', entity_id: booking.id, status: 'success')
    return unless payment

    # Initiate refund via LiqPay
    liqpay = LiqpayService.new
    result = liqpay.refund_payment(order_id: payment.payment_id, amount: payment.amount)

    if result['status'].in?(%w[reversed success])
      # Update payment record
      payment.update!(
        status: 'refunded',
        refunded_at: Time.current,
        refund_amount: payment.amount
      )

      # Update booking payment status
      booking.update!(payment_status_id: PaymentStatus.refunded_id)

      Rails.logger.info "[PaymentAutoRefund] Booking ##{booking.id} refund successful"
    else
      Rails.logger.warn "[PaymentAutoRefund] Booking ##{booking.id} refund failed: #{result['err_description']}"
    end
  rescue LiqpayService::ConfigurationError => e
    Rails.logger.error "[PaymentAutoRefund] LiqPay not configured: #{e.message}"
    # Do not retry configuration errors
  end
end
