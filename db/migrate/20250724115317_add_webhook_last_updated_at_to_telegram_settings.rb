class AddWebhookLastUpdatedAtToTelegramSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :telegram_settings, :webhook_last_updated_at, :datetime
    add_index :telegram_settings, :webhook_last_updated_at
  end
end
