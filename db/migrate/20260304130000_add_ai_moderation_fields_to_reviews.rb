# frozen_string_literal: true

class AddAiModerationFieldsToReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :reviews, :moderation_status, :string, default: 'pending'
    add_column :reviews, :moderation_reason, :string
    add_column :reviews, :moderation_confidence, :float
    add_column :reviews, :moderated_at, :datetime
    add_column :reviews, :ai_sentiment, :string
    add_column :reviews, :ai_classification, :string
    add_column :reviews, :ai_suggested_reply, :text
    add_column :reviews, :ai_is_fake, :boolean, default: false
    add_column :reviews, :ai_metadata, :jsonb, default: {}

    add_index :reviews, :moderation_status
    add_index :reviews, :ai_sentiment
    add_index :reviews, :ai_classification
  end
end
