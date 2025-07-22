class CreatePushSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :push_settings do |t|
      t.string :vapid_public_key
      t.string :vapid_private_key
      t.string :firebase_api_key
      t.string :firebase_project_id
      t.string :firebase_app_id
      t.boolean :enabled, default: false, null: false
      t.boolean :test_mode, default: false, null: false
      t.integer :daily_limit, default: 1000, null: false
      t.integer :rate_limit, default: 100, null: false

      t.timestamps
    end
    
    # Создаем запись по умолчанию
    reversible do |dir|
      dir.up do
        PushSetting.create!(
          enabled: false,
          test_mode: false,
          daily_limit: 1000,
          rate_limit: 100
        )
      end
    end
  end
end
