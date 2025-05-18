class CreateBookingStatuses < ActiveRecord::Migration[8.0]
  def change
    # Статусы бронирований
    create_table :booking_statuses do |t|
      t.string :name, null: false
      t.text :description
      t.string :color, limit: 7
      t.boolean :is_active, default: true
      t.integer :sort_order, default: 0
      t.timestamps
    end
    add_index :booking_statuses, :name, unique: true

    # Статусы оплаты
    create_table :payment_statuses do |t|
      t.string :name, null: false
      t.text :description
      t.string :color, limit: 7
      t.boolean :is_active, default: true
      t.integer :sort_order, default: 0
      t.timestamps
    end

    # Причины отмены бронирования
    create_table :cancellation_reasons do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :is_for_client, default: true
      t.boolean :is_for_partner, default: true
      t.boolean :is_active, default: true
      t.integer :sort_order, default: 0
      t.timestamps
    end

    # Добавляем начальные данные для статусов бронирования
    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO booking_statuses (name, description, color, is_active, sort_order, created_at, updated_at) VALUES
          ('pending', 'Booking has been created but not confirmed', '#FFC107', true, 1, NOW(), NOW()),
          ('confirmed', 'Booking has been confirmed by the service point', '#4CAF50', true, 2, NOW(), NOW()),
          ('in_progress', 'Service is currently being provided', '#2196F3', true, 3, NOW(), NOW()),
          ('completed', 'Service has been successfully completed', '#8BC34A', true, 4, NOW(), NOW()),
          ('canceled_by_client', 'Booking was canceled by the client', '#F44336', true, 5, NOW(), NOW()),
          ('canceled_by_partner', 'Booking was canceled by the partner', '#FF5722', true, 6, NOW(), NOW()),
          ('no_show', 'Client did not show up', '#9C27B0', true, 7, NOW(), NOW());
        SQL
      end
    end

    # Добавляем начальные данные для статусов оплаты
    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO payment_statuses (name, description, color, is_active, sort_order, created_at, updated_at) VALUES
          ('pending', 'Payment is expected', '#FFC107', true, 1, NOW(), NOW()),
          ('paid', 'Payment has been successfully processed', '#4CAF50', true, 2, NOW(), NOW()),
          ('failed', 'Payment attempt failed', '#F44336', true, 3, NOW(), NOW()),
          ('refunded', 'Payment has been refunded', '#2196F3', true, 4, NOW(), NOW()),
          ('partially_refunded', 'Payment has been partially refunded', '#9C27B0', true, 5, NOW(), NOW());
        SQL
      end
    end

    # Добавляем начальные данные для причин отмены
    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO cancellation_reasons (name, is_for_client, is_for_partner, sort_order, created_at, updated_at) VALUES
          ('Schedule change', true, true, 1, NOW(), NOW()),
          ('Found another service provider', true, false, 2, NOW(), NOW()),
          ('Vehicle issue resolved', true, false, 3, NOW(), NOW()),
          ('Weather conditions', true, true, 4, NOW(), NOW()),
          ('Emergency', true, true, 5, NOW(), NOW()),
          ('Staff shortage', false, true, 6, NOW(), NOW()),
          ('Equipment malfunction', false, true, 7, NOW(), NOW()),
          ('Overbooking', false, true, 8, NOW(), NOW()),
          ('Other', true, true, 9, NOW(), NOW());
        SQL
      end
    end
  end
end
