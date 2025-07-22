class AddBotUsernameToTelegramSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :telegram_settings, :bot_username, :string
  end
end
