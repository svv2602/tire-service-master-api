class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      # Связи
      t.references :service_point, null: false, foreign_key: true, comment: 'Сервисная точка для выдачи заказа'
      
      # Основные данные заказа
      t.string :status, null: false, default: 'received', comment: 'Статус заказа'
      t.datetime :order_date, null: false, comment: 'Дата создания заказа'
      t.string :ttn, null: false, comment: 'ТТН (номер накладной)', index: { unique: true }
      t.string :number, comment: 'Номер заказа (может быть пустым)'
      t.string :status_kod, null: false, comment: 'Код статуса из внешней системы'
      t.string :bas_id, null: false, comment: 'ID заказа в системе 1С/BAS'
      t.integer :separate, default: 1, comment: 'Признак разделения заказа'
      
      # Данные о клиенте
      t.string :customer_name, null: false, comment: 'ФИО клиента'
      t.string :customer_phone, null: false, comment: 'Телефон клиента'
      
      # Данные о точке выдачи
      t.string :point_name, null: false, comment: 'Название точки выдачи'
      t.string :point_id, null: false, comment: 'ID точки выдачи во внешней системе'
      t.boolean :third_party_point, default: false, comment: 'Является ли точка сторонней'
      
      # ТТН статусы (для интеграции с службами доставки)
      t.string :ttn_status, comment: 'Статус ТТН'
      t.string :ttn_status_kod, comment: 'Код статуса ТТН'
      
      # Итоговые суммы (рассчитываются автоматически)
      t.decimal :total_amount, precision: 10, scale: 2, null: false, comment: 'Общая сумма заказа'
      t.integer :total_quantity, null: false, comment: 'Общее количество товаров'
      
      # Метки времени обработки
      t.datetime :processed_at, comment: 'Время начала обработки'
      t.datetime :ready_at, comment: 'Время готовности к выдаче'
      t.datetime :delivered_at, comment: 'Время выдачи клиенту'
      t.datetime :canceled_at, comment: 'Время отмены'
      t.text :cancellation_reason, comment: 'Причина отмены'
      
      # Дополнительные поля
      t.text :notes, comment: 'Дополнительные заметки'
      t.json :metadata, comment: 'Дополнительные данные в JSON формате'
      
      t.timestamps
    end
    
    # Индексы для оптимизации запросов
    add_index :orders, [:service_point_id, :status]
    add_index :orders, [:customer_phone]
    add_index :orders, [:order_date]
    add_index :orders, [:bas_id]
    add_index :orders, [:point_id]
    
    # Полнотекстовый поиск по клиентам
    add_index :orders, "to_tsvector('russian', customer_name)", 
              using: :gin, name: 'idx_orders_customer_search'
  end
end 