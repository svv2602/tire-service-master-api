# Background job for delivering webhook payloads.
# Uses Sidekiq with the :webhooks queue.
class WebhookDeliveryJob < ApplicationJob
  queue_as :webhooks

  # Sidekiq retry configuration: disable Sidekiq's own retries
  # since WebhookDeliveryService handles retries internally.
  sidekiq_options retry: 0

  def perform(delivery_id)
    WebhookDeliveryService.deliver(delivery_id)
  end
end
