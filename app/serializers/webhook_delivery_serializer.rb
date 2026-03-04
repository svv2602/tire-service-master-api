# Serializer for webhook delivery records shown to partners
class WebhookDeliverySerializer
  include JSONAPI::Serializer

  attributes :id, :event, :status, :response_code, :attempt,
             :delivered_at, :error_message, :created_at

  # Include payload only when specifically requested
  attribute :payload, if: proc { |_record, params|
    params && params[:include_payload]
  }
end
