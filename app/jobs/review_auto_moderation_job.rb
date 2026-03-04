# frozen_string_literal: true

# Background job for AI-powered review auto-moderation
# Triggered after_create on Review model
#
# Runs ReviewModerationService to classify, analyze sentiment,
# and auto-publish or flag reviews based on AI confidence
class ReviewAutoModerationJob < ApplicationJob
  queue_as :default

  # Retry with exponential backoff if moderation fails
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(review_id)
    review = Review.find_by(id: review_id)
    return unless review

    # Skip if already moderated
    return if review.moderation_status.present? && review.moderation_status != 'pending'

    Rails.logger.info "[ReviewAutoModerationJob] Starting moderation for review #{review_id}"

    service = ReviewModerationService.new
    result = service.moderate(review)

    Rails.logger.info "[ReviewAutoModerationJob] Review #{review_id} moderated: " \
                      "classification=#{result[:classification]}, " \
                      "status=#{result[:status]}, " \
                      "confidence=#{result[:confidence]}"

    # Generate suggested reply if review was approved
    if result[:status] == 'approved'
      generate_suggested_reply(review)
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "[ReviewAutoModerationJob] Review #{review_id} not found, skipping"
  end

  private

  def generate_suggested_reply(review)
    return unless defined?(ReviewReplyGeneratorService)

    generator = ReviewReplyGeneratorService.new
    reply_result = generator.generate(review)

    if reply_result[:suggested_reply].present?
      review.update(ai_suggested_reply: reply_result[:suggested_reply])
      Rails.logger.info "[ReviewAutoModerationJob] Generated reply suggestion for review #{review.id}"
    end
  rescue StandardError => e
    Rails.logger.warn "[ReviewAutoModerationJob] Failed to generate reply for review #{review.id}: #{e.message}"
  end
end
