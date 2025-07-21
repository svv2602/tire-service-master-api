class CreateTelegramSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :telegram_settings do |t|
      t.string :bot_token
      t.string :webhook_url
      t.string :admin_chat_id
      t.boolean :enabled, default: false, null: false
      t.boolean :test_mode, default: false, null: false
      t.boolean :auto_subscription, default: true, null: false
      t.text :welcome_message
      t.text :help_message
      t.text :error_message

      t.timestamps
    end
    
    # Создаем запись по умолчанию
    reversible do |dir|
      dir.up do
        TelegramSetting.create!(
          enabled: false,
          test_mode: false,
          auto_subscription: true,
          welcome_message: 'Ласкаво просимо до системи сповіщень шиномонтажу! 🚗\n\nТепер ви будете отримувати сповіщення про ваші записи.',
          help_message: 'Доступні команди:\n/start - Почати роботу з ботом\n/help - Показати це повідомлення\n/status - Статус підписки\n/unsubscribe - Скасувати підписку',
          error_message: 'Вибачте, сталася помилка. Спробуйте пізніше або зверніться до підтримки.'
        )
      end
    end
  end
end
