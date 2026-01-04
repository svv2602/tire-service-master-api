# frozen_string_literal: true

class CreateConversations < ActiveRecord::Migration[8.0]
  def change
    create_table :conversations do |t|
      t.references :user, null: true, foreign_key: true
      t.string :session_id, null: false
      t.string :status, default: 'active', null: false
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :conversations, :session_id
    add_index :conversations, :status
    add_index :conversations, [:user_id, :status]
    add_index :conversations, :created_at
  end
end
