class CreateOrderItems < ActiveRecord::Migration[8.0]
  def change
    create_table :order_items do |t|
      # Связи
      t.references :order, null: false, foreign_key: true, comment: 'Заказ, к которому относится товар'
      
      # Данные о товаре
      t.string :artikul, null: false, comment: 'Артикул товара'
      t.integer :quantity, null: false, comment: 'Количество товара'
      t.decimal :price, precision: 10, scale: 2, null: false, comment: 'Цена за единицу товара'
      t.decimal :sum, precision: 10, scale: 2, null: false, comment: 'Общая стоимость (quantity * price)'
      t.string :bas_id, null: false, comment: 'ID товара в системе 1С/BAS'
      
      # Дополнительные данные о товаре
      t.string :name, comment: 'Название товара'
      t.text :description, comment: 'Описание товара'
      t.string :category, comment: 'Категория товара'
      t.string :brand, comment: 'Бренд товара'
      t.string :model, comment: 'Модель товара'
      t.json :attributes, comment: 'Дополнительные атрибуты товара в JSON'
      
      t.timestamps
    end
    
    # Индексы для оптимизации
    add_index :order_items, [:order_id, :artikul]
    add_index :order_items, [:artikul]
    add_index :order_items, [:bas_id]
  end
end 