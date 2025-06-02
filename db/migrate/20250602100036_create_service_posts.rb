class CreateServicePosts < ActiveRecord::Migration[8.0]
  def change
    create_table :service_posts do |t|
      t.references :service_point, null: false, foreign_key: true
      t.integer :post_number, null: false
      t.string :name, limit: 255
      t.integer :slot_duration, null: false, default: 60
      t.boolean :is_active, default: true, null: false
      t.text :description

      t.timestamps
    end
    
    # Уникальный индекс на комбинацию service_point_id + post_number
    add_index :service_posts, [:service_point_id, :post_number], 
              unique: true, name: 'index_service_posts_on_service_point_and_post_number'
    
    # Индекс для быстрого поиска активных постов
    add_index :service_posts, [:service_point_id, :is_active], 
              name: 'index_service_posts_on_service_point_and_active'
  end
end
