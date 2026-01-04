class CreateReviewReplyTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :review_reply_templates do |t|
      t.string :name, null: false
      t.text :content, null: false
      t.string :category, default: 'general'
      t.boolean :is_active, default: true
      t.references :partner, null: true, foreign_key: true
      t.integer :sort_order, default: 0
      t.integer :usage_count, default: 0

      t.timestamps
    end

    add_index :review_reply_templates, :category
    add_index :review_reply_templates, :is_active
    add_index :review_reply_templates, [:partner_id, :is_active]
  end
end
