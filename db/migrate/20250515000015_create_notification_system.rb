class CreateNotificationSystem < ActiveRecord::Migration[8.0]
  def change
    # Типы уведомлений
    create_table :notification_types do |t|
      t.string :name, null: false
      t.text :template
      t.boolean :is_push, default: false
      t.boolean :is_email, default: false
      t.boolean :is_sms, default: false
      t.boolean :is_active, default: true
      t.timestamps
    end

    # Уведомления
    create_table :notifications do |t|
      t.references :notification_type, null: false, foreign_key: true
      t.string :recipient_type, null: false # 'user', 'client', 'partner', 'manager', 'administrator'
      t.integer :recipient_id, null: false
      t.string :title, null: false
      t.text :message, null: false
      t.string :send_via, null: false # 'push', 'email', 'sms'
      t.datetime :sent_at
      t.datetime :read_at
      t.boolean :is_read, default: false
      t.timestamps
    end

    # Создаем индексы для уведомлений
    add_index :notifications, [:recipient_type, :recipient_id], name: 'idx_notifications_recipient'
    add_index :notifications, :is_read
    add_index :notifications, :sent_at

    # Системные логи
    create_table :system_logs do |t|
      t.references :user, foreign_key: true
      t.string :action, null: false
      t.string :entity_type
      t.integer :entity_id
      t.jsonb :old_value
      t.jsonb :new_value
      t.string :ip_address, limit: 45
      t.text :user_agent
      t.timestamps
    end

    add_index :system_logs, :action
    add_index :system_logs, [:entity_type, :entity_id], name: 'idx_system_logs_entity'
    add_index :system_logs, :created_at

    # Добавляем начальные данные для типов уведомлений
    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO notification_types (name, template, is_push, is_email, is_sms, created_at, updated_at) VALUES
          ('booking_created', 'Your booking has been created: {{date}} at {{time}}', true, true, false, NOW(), NOW()),
          ('booking_confirmed', 'Your booking has been confirmed: {{date}} at {{time}}', true, true, true, NOW(), NOW()),
          ('booking_reminder', 'Reminder: Your appointment is tomorrow at {{time}}', true, true, true, NOW(), NOW()),
          ('booking_canceled', 'Your booking for {{date}} has been canceled', true, true, true, NOW(), NOW()),
          ('booking_completed', 'Thank you for visiting us! Please rate your experience', true, true, false, NOW(), NOW()),
          ('partner_new_booking', 'New booking received for {{date}} at {{time}}', true, true, false, NOW(), NOW()),
          ('partner_booking_canceled', 'Booking for {{date}} at {{time}} has been canceled', true, true, false, NOW(), NOW());
        SQL
      end
    end
  end
end
