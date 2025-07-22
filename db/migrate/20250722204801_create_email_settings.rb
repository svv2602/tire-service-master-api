class CreateEmailSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :email_settings do |t|
      t.string :smtp_host
      t.integer :smtp_port, default: 587
      t.string :smtp_username
      t.string :smtp_password
      t.string :smtp_authentication, default: 'plain'
      t.boolean :smtp_starttls_auto, default: true, null: false
      t.boolean :smtp_tls, default: false, null: false
      t.string :from_email
      t.string :from_name
      t.boolean :enabled, default: false, null: false
      t.boolean :test_mode, default: false, null: false

      t.timestamps
    end
    
    # Создаем запись по умолчанию
    reversible do |dir|
      dir.up do
        EmailSetting.create!(
          enabled: false,
          smtp_port: 587,
          smtp_authentication: nil,  # Без аутентификации по умолчанию
          smtp_starttls_auto: true,
          smtp_tls: false,
          test_mode: false,
          from_name: 'Tire Service'
        )
      end
    end
  end
end
