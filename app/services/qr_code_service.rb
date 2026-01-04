# frozen_string_literal: true

require 'rqrcode'
require 'base64'

# Service for generating and verifying QR codes for order pickup
class QrCodeService
  class InvalidTokenError < StandardError; end
  class OrderNotReadyError < StandardError; end
  class AlreadyScannedError < StandardError; end

  # Generate a unique QR code token for an order
  # @param order [Order, TireOrder] the order to generate QR for
  # @return [String] the generated token
  def self.generate_token(order)
    # Create a unique token based on order type, id, and random string
    order_type = order.class.name.underscore
    timestamp = Time.current.to_i
    random = SecureRandom.hex(8)

    token = "#{order_type}_#{order.id}_#{timestamp}_#{random}"

    # Store the token
    order.update_column(:qr_code_token, token)

    token
  end

  # Generate QR code image as SVG
  # @param order [Order, TireOrder] the order
  # @param size [Integer] module size for QR code
  # @return [String] SVG string
  def self.generate_svg(order, size: 4)
    token = order.qr_code_token || generate_token(order)

    # Create QR code with order pickup URL
    qr_data = build_qr_data(order, token)
    qrcode = RQRCode::QRCode.new(qr_data)

    qrcode.as_svg(
      color: '000',
      shape_rendering: 'crispEdges',
      module_size: size,
      standalone: true,
      use_path: true
    )
  end

  # Generate QR code as PNG base64
  # @param order [Order, TireOrder] the order
  # @return [String] base64 encoded PNG
  def self.generate_png_base64(order)
    token = order.qr_code_token || generate_token(order)

    qr_data = build_qr_data(order, token)
    qrcode = RQRCode::QRCode.new(qr_data)

    png = qrcode.as_png(
      bit_depth: 1,
      border_modules: 2,
      color_mode: ChunkyPNG::COLOR_GRAYSCALE,
      color: 'black',
      file: nil,
      fill: 'white',
      module_px_size: 6,
      resize_exactly_to: false,
      resize_gte_to: false,
      size: 300
    )

    Base64.strict_encode64(png.to_s)
  end

  # Verify and process QR code scan
  # @param token [String] the scanned QR token
  # @param user [User] the user who scanned (operator/manager)
  # @return [Hash] result with order info
  def self.verify_and_process(token, user)
    # Parse token to find order
    order = find_order_by_token(token)

    raise InvalidTokenError, 'Invalid QR code token' unless order
    raise AlreadyScannedError, 'Order already picked up' if order.qr_scanned_at.present?
    raise OrderNotReadyError, 'Order is not ready for pickup' unless order_ready?(order)

    # Mark order as delivered
    ActiveRecord::Base.transaction do
      order.update!(
        qr_scanned_at: Time.current,
        qr_scanned_by_id: user.id,
        status: 'delivered'
      )
    end

    {
      success: true,
      order_type: order.class.name,
      order_id: order.id,
      order_number: order.respond_to?(:ttn) ? order.ttn : order.order_number,
      customer_name: order.customer_name,
      delivered_at: order.qr_scanned_at
    }
  end

  private

  # Build the data to encode in QR code
  def self.build_qr_data(order, token)
    # Include essential info that can be used offline too
    base_url = ENV.fetch('FRONTEND_URL', 'http://localhost:3008')
    "#{base_url}/order-pickup?token=#{token}"
  end

  # Find order by QR token
  def self.find_order_by_token(token)
    # Try to find in orders table first
    order = Order.find_by(qr_code_token: token)
    return order if order

    # Try tire_orders
    TireOrder.find_by(qr_code_token: token)
  end

  # Check if order is ready for pickup
  def self.order_ready?(order)
    case order
    when Order
      order.status_ready?
    when TireOrder
      order.status == 'ready' || order.status == 'ready_for_pickup'
    else
      false
    end
  end
end
