class CreateBookingsAndRelatedTables < ActiveRecord::Migration[8.0]
  def change
    # Бронирования
    create_table :bookings do |t|
      t.references :client, null: false, foreign_key: true
      t.references :service_point, null: false, foreign_key: true
      t.references :car, foreign_key: { to_table: :client_cars }
      t.references :slot, null: false, foreign_key: { to_table: :schedule_slots }
      t.date :booking_date, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.references :status, null: false, foreign_key: { to_table: :booking_statuses }
      t.references :payment_status, foreign_key: { to_table: :payment_statuses }
      t.references :cancellation_reason, foreign_key: true
      t.text :cancellation_comment
      t.decimal :total_price, precision: 10, scale: 2
      t.string :payment_method
      t.text :notes
      t.timestamps
    end

    # Услуги в бронировании
    create_table :booking_services do |t|
      t.references :booking, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.decimal :price, precision: 10, scale: 2, null: false
      t.integer :quantity, default: 1
      t.timestamps
    end

    # Избранные точки клиентов
    create_table :client_favorite_points do |t|
      t.references :client, null: false, foreign_key: true
      t.references :service_point, null: false, foreign_key: true
      t.timestamps
    end
    add_index :client_favorite_points, [:client_id, :service_point_id], unique: true, name: 'idx_unique_client_favorite_point'

    # Отзывы
    create_table :reviews do |t|
      t.references :booking, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.references :service_point, null: false, foreign_key: true
      t.integer :rating, null: false
      t.text :comment
      t.text :partner_response
      t.boolean :is_published, default: true
      t.timestamps
    end
    add_check_constraint :reviews, "rating BETWEEN 1 AND 5", name: "check_rating_range"
  end
end
