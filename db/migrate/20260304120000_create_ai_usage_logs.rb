# frozen_string_literal: true

# Phase-02: AI usage logging for cost monitoring and analytics
class CreateAiUsageLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_usage_logs do |t|
      t.references :user, null: true, foreign_key: true
      t.string :service_name, null: false         # e.g. 'tire_search', 'tire_chat', 'tire_normalization'
      t.string :operation, null: false             # e.g. 'tire_search_llm_parsing', 'tire_chat_completion'
      t.integer :tokens_input, default: 0          # input tokens used
      t.integer :tokens_output, default: 0         # output tokens used
      t.string :model                              # e.g. 'gpt-4.1-mini'
      t.decimal :cost_estimate, precision: 10, scale: 6, default: 0  # estimated cost in USD
      t.integer :latency_ms, default: 0            # request latency in ms
      t.integer :attempts, default: 1              # number of retry attempts
      t.boolean :success, default: true, null: false
      t.boolean :from_cache, default: false, null: false  # whether result came from cache
      t.string :error_message                      # error details if failed
      t.string :ip_address                         # client IP for anonymous users
      t.jsonb :metadata, default: {}               # additional data (query hash, etc.)

      t.timestamps
    end

    add_index :ai_usage_logs, :service_name
    add_index :ai_usage_logs, :operation
    add_index :ai_usage_logs, :created_at
    add_index :ai_usage_logs, [:user_id, :service_name]
    add_index :ai_usage_logs, [:service_name, :created_at]
    add_index :ai_usage_logs, :success
  end
end
