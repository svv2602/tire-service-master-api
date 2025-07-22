class CreateNotificationChannelSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :notification_channel_settings do |t|
      t.string :channel_type, null: false
      t.boolean :enabled, default: true, null: false
      t.integer :priority, default: 1, null: false
      t.integer :retry_attempts, default: 3, null: false
      t.integer :retry_delay, default: 15, null: false # в минутах
      t.integer :daily_limit, default: 1000, null: false
      t.integer :rate_limit_per_minute, default: 60, null: false

      t.timestamps
    end

    # Добавляем индексы
    add_index :notification_channel_settings, :channel_type, unique: true
    add_index :notification_channel_settings, :enabled
    add_index :notification_channel_settings, :priority

    # Создаем настройки по умолчанию для каждого канала
    reversible do |dir|
      dir.up do
        # Email канал
        execute <<-SQL
          INSERT INTO notification_channel_settings 
          (channel_type, enabled, priority, retry_attempts, retry_delay, daily_limit, rate_limit_per_minute, created_at, updated_at)
          VALUES 
          ('email', true, 1, 3, 15, 1000, 60, NOW(), NOW())
        SQL

        # Push канал
        execute <<-SQL
          INSERT INTO notification_channel_settings 
          (channel_type, enabled, priority, retry_attempts, retry_delay, daily_limit, rate_limit_per_minute, created_at, updated_at)
          VALUES 
          ('push', true, 2, 2, 5, 2000, 120, NOW(), NOW())
        SQL

        # Telegram канал
        execute <<-SQL
          INSERT INTO notification_channel_settings 
          (channel_type, enabled, priority, retry_attempts, retry_delay, daily_limit, rate_limit_per_minute, created_at, updated_at)
          VALUES 
          ('telegram', true, 3, 3, 10, 1500, 100, NOW(), NOW())
        SQL
      end
    end
  end
end
