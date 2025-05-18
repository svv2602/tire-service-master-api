class CreateServiceAndPriceTables < ActiveRecord::Migration[8.0]
  def change
    # Категории услуг
    create_table :service_categories do |t|
      t.string :name, null: false
      t.text :description
      t.string :icon_url
      t.integer :sort_order, default: 0
      t.boolean :is_active, default: true
      t.timestamps
    end
    add_index :service_categories, :name, unique: true

    # Услуги
    create_table :services do |t|
      t.references :category, null: false, foreign_key: { to_table: :service_categories }
      t.string :name, null: false
      t.text :description
      t.integer :default_duration, default: 60 # минуты
      t.integer :sort_order, default: 0
      t.boolean :is_active, default: true
      t.timestamps
    end

    # Прайс-листы
    create_table :price_lists do |t|
      t.references :partner, null: false, foreign_key: true
      t.references :service_point, foreign_key: true
      t.string :name, null: false
      t.string :season # 'winter', 'summer', etc.
      t.date :start_date
      t.date :end_date
      t.boolean :is_active, default: true
      t.timestamps
    end
    add_index :price_lists, [:start_date, :end_date], name: 'idx_price_lists_date_range'

    # Элементы прайс-листа
    create_table :price_list_items do |t|
      t.references :price_list, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.decimal :price, precision: 10, scale: 2, null: false
      t.decimal :discount_price, precision: 10, scale: 2
      t.timestamps
    end
    add_index :price_list_items, [:price_list_id, :service_id], unique: true

    # Акции и специальные предложения
    create_table :promotions do |t|
      t.references :partner, null: false, foreign_key: true
      t.references :service_point, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.integer :discount_percent
      t.decimal :discount_amount, precision: 10, scale: 2
      t.boolean :is_active, default: true
      t.timestamps
    end
    add_index :promotions, [:start_date, :end_date], name: 'idx_promotions_date_range'
  end
end
