# frozen_string_literal: true

class CreateReviewRequestTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :review_request_tokens do |t|
      t.string :token, null: false
      t.references :booking, null: false, foreign_key: true
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :review_request_tokens, :token, unique: true
    add_index :review_request_tokens, :expires_at

    # Add review_request_sent_at to bookings if not exists
    unless column_exists?(:bookings, :review_request_sent_at)
      add_column :bookings, :review_request_sent_at, :datetime
      add_index :bookings, :review_request_sent_at
    end
  end
end
