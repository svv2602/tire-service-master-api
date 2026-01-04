# frozen_string_literal: true

# Create chat_analytics table for tracking tire chat interactions
class CreateChatAnalytics < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_analytics do |t|
      t.references :conversation, null: true, foreign_key: true
      t.references :conversation_message, null: true, foreign_key: true
      t.string :session_id, null: false
      t.text :user_query, null: false
      t.text :normalized_query
      t.string :response_type, null: false, default: 'general'
      t.string :intent
      t.jsonb :products_shown, default: []
      t.integer :products_count, default: 0
      t.integer :response_time_ms
      t.boolean :had_results, default: false
      t.boolean :is_quick_question, default: false
      t.boolean :is_brand_comparison, default: false
      t.jsonb :filters_used, default: {}
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :chat_analytics, :session_id
    add_index :chat_analytics, :response_type
    add_index :chat_analytics, :intent
    add_index :chat_analytics, :had_results
    add_index :chat_analytics, :created_at
    add_index :chat_analytics, [:normalized_query, :had_results]
  end
end
