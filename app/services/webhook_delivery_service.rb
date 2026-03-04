# Service for delivering webhook payloads to partner endpoints.
# Sends POST requests with JSON payloads signed with HMAC-SHA256.
# Supports retry with exponential backoff (3 attempts).
class WebhookDeliveryService < ApplicationService
  MAX_RETRIES = 3
  BASE_DELAY = 2 # seconds
  REQUEST_TIMEOUT = 10 # seconds

  def initialize(event:, payload:, partner: nil)
    @event = event
    @payload = payload
    @partner = partner
  end

  def call
    endpoints = find_endpoints
    return if endpoints.empty?

    endpoints.each do |endpoint|
      delivery = create_delivery_record(endpoint)
      WebhookDeliveryJob.perform_later(delivery.id)
    end
  end

  # Perform the actual HTTP delivery for a single WebhookDelivery record.
  # Called by WebhookDeliveryJob.
  def self.deliver(delivery_id)
    delivery = WebhookDelivery.find(delivery_id)
    endpoint = delivery.webhook_endpoint

    return unless endpoint.is_active?

    attempt = 0
    last_error = nil

    while attempt < MAX_RETRIES
      attempt += 1
      delivery.update!(attempt: attempt)

      begin
        response = send_request(endpoint, delivery)

        if response.code.to_i.between?(200, 299)
          delivery.mark_success!(
            response_code: response.code.to_i,
            response_body: response.body
          )
          Rails.logger.info "[WebhookDeliveryService] Delivered #{delivery.event} to #{endpoint.url} (attempt #{attempt})"
          return
        else
          last_error = "HTTP #{response.code}: #{response.body}"
          Rails.logger.warn "[WebhookDeliveryService] Non-success response for #{delivery.event} to #{endpoint.url}: #{last_error} (attempt #{attempt})"
        end
      rescue StandardError => e
        last_error = "#{e.class}: #{e.message}"
        Rails.logger.warn "[WebhookDeliveryService] Error delivering #{delivery.event} to #{endpoint.url}: #{last_error} (attempt #{attempt})"
      end

      # Exponential backoff before next retry
      if attempt < MAX_RETRIES
        delay = BASE_DELAY**attempt
        sleep(delay)
      end
    end

    # All retries exhausted
    delivery.mark_failed!(error_message: last_error)
    Rails.logger.error "[WebhookDeliveryService] Failed to deliver #{delivery.event} to #{endpoint.url} after #{MAX_RETRIES} attempts"
  end

  private

  def find_endpoints
    if @partner
      WebhookEndpoint.where(partner: @partner).for_event(@event)
    else
      WebhookEndpoint.for_event(@event)
    end
  end

  def create_delivery_record(endpoint)
    endpoint.webhook_deliveries.create!(
      event: @event,
      payload: @payload,
      status: 'pending'
    )
  end

  # Send the HTTP POST request with HMAC-SHA256 signature
  def self.send_request(endpoint, delivery)
    uri = URI.parse(endpoint.url)
    body = delivery.payload.to_json
    signature = compute_signature(endpoint.secret, body)
    timestamp = Time.current.to_i.to_s

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = REQUEST_TIMEOUT
    http.read_timeout = REQUEST_TIMEOUT

    request = Net::HTTP::Post.new(uri.request_uri)
    request['Content-Type'] = 'application/json'
    request['X-Webhook-Signature'] = "sha256=#{signature}"
    request['X-Webhook-Event'] = delivery.event
    request['X-Webhook-Delivery-Id'] = delivery.id.to_s
    request['X-Webhook-Timestamp'] = timestamp
    request['User-Agent'] = 'TireService-Webhook/1.0'
    request.body = body

    http.request(request)
  end

  # Compute HMAC-SHA256 signature for payload verification
  def self.compute_signature(secret, body)
    OpenSSL::HMAC.hexdigest('SHA256', secret, body)
  end
end
