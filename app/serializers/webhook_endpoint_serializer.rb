# Serializer for webhook endpoint data returned to the partner
class WebhookEndpointSerializer
  include JSONAPI::Serializer

  attributes :id, :url, :events, :is_active, :description, :created_at, :updated_at

  # Expose masked secret (only last 8 characters visible)
  attribute :secret_masked do |endpoint|
    secret = endpoint.secret
    if secret && secret.length > 8
      "#{'*' * (secret.length - 8)}#{secret[-8..]}"
    else
      '********'
    end
  end

  # Total delivery count
  attribute :deliveries_count do |endpoint|
    endpoint.webhook_deliveries.count
  end

  # Last successful delivery timestamp
  attribute :last_delivery_at do |endpoint|
    endpoint.webhook_deliveries.successful.order(delivered_at: :desc).first&.delivered_at
  end
end
