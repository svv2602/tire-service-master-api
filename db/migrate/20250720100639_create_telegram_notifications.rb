class CreateTelegramNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :telegram_notifications do |t|
      t.timestamps
    end
  end
end
