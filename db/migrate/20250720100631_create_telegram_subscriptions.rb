class CreateTelegramSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :telegram_subscriptions do |t|
      t.timestamps
    end
  end
end
