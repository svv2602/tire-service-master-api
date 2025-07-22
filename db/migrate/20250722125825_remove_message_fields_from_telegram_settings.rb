class RemoveMessageFieldsFromTelegramSettings < ActiveRecord::Migration[8.0]
  def change
    remove_column :telegram_settings, :welcome_message, :text
    remove_column :telegram_settings, :help_message, :text
    remove_column :telegram_settings, :error_message, :text
  end
end
