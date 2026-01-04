# frozen_string_literal: true

class CreateConversationMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :conversation_messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :role, null: false # user, assistant, system
      t.text :content, null: false
      t.jsonb :metadata, default: {} # products, search_params, etc.

      t.timestamps
    end

    add_index :conversation_messages, :role
    add_index :conversation_messages, :created_at
  end
end
