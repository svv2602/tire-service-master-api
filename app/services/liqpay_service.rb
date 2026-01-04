# LiqPay Payment Service for Ukrainian payment processing
# Documentation: https://www.liqpay.ua/documentation/api/aquiring
class LiqpayService
  LIQPAY_API_URL = 'https://www.liqpay.ua/api/3/checkout'.freeze
  LIQPAY_REQUEST_URL = 'https://www.liqpay.ua/api/request'.freeze

  class PaymentError < StandardError; end
  class ConfigurationError < StandardError; end

  def initialize
    @public_key = ENV['LIQPAY_PUBLIC_KEY']
    @private_key = ENV['LIQPAY_PRIVATE_KEY']
    @sandbox_mode = ENV['LIQPAY_SANDBOX'] == 'true'

    validate_configuration!
  end

  # Create payment for booking
  # @param booking [Booking] the booking to pay for
  # @param amount [Decimal] payment amount in UAH
  # @param description [String] payment description
  # @return [Hash] payment data with checkout URL
  def create_booking_payment(booking:, amount:, description: nil)
    order_id = generate_order_id(booking)

    payment_description = description || build_booking_description(booking)

    create_payment(
      order_id: order_id,
      amount: amount,
      currency: 'UAH',
      description: payment_description,
      result_url: "#{frontend_url}/client/bookings/#{booking.id}?payment=success",
      server_url: "#{api_url}/api/v1/payments/liqpay/callback",
      payload: {
        booking_id: booking.id,
        payment_type: 'booking'
      }
    )
  end

  # Create payment for tire order
  # @param order [TireOrder] the order to pay for
  # @param amount [Decimal] payment amount in UAH
  # @return [Hash] payment data with checkout URL
  def create_order_payment(order:, amount:, description: nil)
    order_id = "order_#{order.id}_#{Time.current.to_i}"

    payment_description = description || "Оплата замовлення шин ##{order.id}"

    create_payment(
      order_id: order_id,
      amount: amount,
      currency: 'UAH',
      description: payment_description,
      result_url: "#{frontend_url}/client/orders/#{order.id}?payment=success",
      server_url: "#{api_url}/api/v1/payments/liqpay/callback",
      payload: {
        order_id: order.id,
        payment_type: 'tire_order'
      }
    )
  end

  # Process callback from LiqPay
  # @param data [String] Base64 encoded data from LiqPay
  # @param signature [String] signature to verify
  # @return [Hash] parsed and verified payment result
  def process_callback(data:, signature:)
    # Verify signature
    expected_signature = calculate_signature(data)
    unless secure_compare(signature, expected_signature)
      raise PaymentError, 'Invalid payment signature'
    end

    # Decode and parse data
    decoded_data = JSON.parse(Base64.decode64(data))

    Rails.logger.info "[LiqPay] Callback received: #{decoded_data.except('card_token', 'sender_card_mask2')}"

    # Extract payment info
    payment_result = {
      status: decoded_data['status'],
      order_id: decoded_data['order_id'],
      payment_id: decoded_data['payment_id'],
      amount: decoded_data['amount'].to_f,
      currency: decoded_data['currency'],
      description: decoded_data['description'],
      transaction_id: decoded_data['transaction_id'],
      sender_phone: decoded_data['sender_phone'],
      err_code: decoded_data['err_code'],
      err_description: decoded_data['err_description'],
      info: decoded_data['info'] ? JSON.parse(decoded_data['info']) : nil,
      raw_data: decoded_data
    }

    # Process based on status
    case payment_result[:status]
    when 'success', 'sandbox'
      handle_successful_payment(payment_result)
    when 'failure', 'error'
      handle_failed_payment(payment_result)
    when 'reversed'
      handle_reversed_payment(payment_result)
    when 'wait_accept'
      handle_pending_payment(payment_result)
    else
      Rails.logger.warn "[LiqPay] Unknown payment status: #{payment_result[:status]}"
    end

    payment_result
  end

  # Check payment status
  # @param order_id [String] order ID to check
  # @return [Hash] payment status
  def check_payment_status(order_id)
    params = {
      version: 3,
      action: 'status',
      public_key: @public_key,
      order_id: order_id
    }

    data = Base64.strict_encode64(params.to_json)
    signature = calculate_signature(data)

    response = HTTParty.post(
      LIQPAY_REQUEST_URL,
      body: { data: data, signature: signature }
    )

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error "[LiqPay] Status check failed: #{e.message}"
    { status: 'error', error: e.message }
  end

  # Refund payment
  # @param order_id [String] original order ID
  # @param amount [Decimal] amount to refund
  # @return [Hash] refund result
  def refund_payment(order_id:, amount:)
    params = {
      version: 3,
      action: 'refund',
      public_key: @public_key,
      order_id: order_id,
      amount: amount
    }

    data = Base64.strict_encode64(params.to_json)
    signature = calculate_signature(data)

    response = HTTParty.post(
      LIQPAY_REQUEST_URL,
      body: { data: data, signature: signature }
    )

    result = JSON.parse(response.body)
    Rails.logger.info "[LiqPay] Refund result: #{result}"

    result
  rescue StandardError => e
    Rails.logger.error "[LiqPay] Refund failed: #{e.message}"
    { status: 'error', error: e.message }
  end

  private

  def validate_configuration!
    raise ConfigurationError, 'LIQPAY_PUBLIC_KEY is not configured' if @public_key.blank?
    raise ConfigurationError, 'LIQPAY_PRIVATE_KEY is not configured' if @private_key.blank?
  end

  def create_payment(order_id:, amount:, currency:, description:, result_url:, server_url:, payload: {})
    params = {
      version: 3,
      public_key: @public_key,
      action: 'pay',
      amount: amount.to_f.round(2),
      currency: currency,
      description: description,
      order_id: order_id,
      result_url: result_url,
      server_url: server_url,
      sandbox: @sandbox_mode ? 1 : 0,
      info: payload.to_json
    }

    data = Base64.strict_encode64(params.to_json)
    signature = calculate_signature(data)

    {
      checkout_url: LIQPAY_API_URL,
      data: data,
      signature: signature,
      order_id: order_id,
      amount: amount,
      sandbox: @sandbox_mode
    }
  end

  def calculate_signature(data)
    sign_string = @private_key + data + @private_key
    Base64.strict_encode64(Digest::SHA1.digest(sign_string))
  end

  def secure_compare(a, b)
    return false unless a.bytesize == b.bytesize

    l = a.unpack('C*')
    res = 0
    b.each_byte { |byte| res |= byte ^ l.shift }
    res == 0
  end

  def generate_order_id(booking)
    "booking_#{booking.id}_#{Time.current.to_i}"
  end

  def build_booking_description(booking)
    service_point_name = booking.service_point&.name || 'СТО'
    date = booking.booking_date&.strftime('%d.%m.%Y') || ''
    time = booking.start_time&.strftime('%H:%M') || ''

    "Оплата запису на #{service_point_name}, #{date} о #{time}"
  end

  def handle_successful_payment(result)
    info = result[:info] || {}

    if info['payment_type'] == 'booking' && info['booking_id']
      booking = Booking.find_by(id: info['booking_id'])
      if booking
        booking.update!(
          payment_status_id: PaymentStatus.paid_id,
          payment_transaction_id: result[:transaction_id],
          payment_amount: result[:amount],
          paid_at: Time.current
        )

        # Send notification
        NotificationService.send_payment_successful(booking)

        Rails.logger.info "[LiqPay] Booking ##{booking.id} payment successful"
      end
    elsif info['payment_type'] == 'tire_order' && info['order_id']
      order = TireOrder.find_by(id: info['order_id'])
      if order
        order.update!(
          payment_status: 'paid',
          payment_transaction_id: result[:transaction_id],
          paid_at: Time.current
        )

        Rails.logger.info "[LiqPay] Order ##{order.id} payment successful"
      end
    end
  end

  def handle_failed_payment(result)
    info = result[:info] || {}

    if info['payment_type'] == 'booking' && info['booking_id']
      booking = Booking.find_by(id: info['booking_id'])
      booking&.update!(payment_status_id: PaymentStatus.failed_id)

      Rails.logger.warn "[LiqPay] Booking ##{info['booking_id']} payment failed: #{result[:err_description]}"
    elsif info['payment_type'] == 'tire_order' && info['order_id']
      order = TireOrder.find_by(id: info['order_id'])
      order&.update!(payment_status: 'failed')

      Rails.logger.warn "[LiqPay] Order ##{info['order_id']} payment failed: #{result[:err_description]}"
    end
  end

  def handle_reversed_payment(result)
    info = result[:info] || {}

    if info['payment_type'] == 'booking' && info['booking_id']
      booking = Booking.find_by(id: info['booking_id'])
      booking&.update!(payment_status_id: PaymentStatus.refunded_id)

      Rails.logger.info "[LiqPay] Booking ##{info['booking_id']} payment reversed"
    end
  end

  def handle_pending_payment(result)
    Rails.logger.info "[LiqPay] Payment pending acceptance: #{result[:order_id]}"
  end

  def frontend_url
    ENV['FRONTEND_URL'] || 'http://localhost:3008'
  end

  def api_url
    ENV['API_URL'] || 'http://localhost:8000'
  end
end
