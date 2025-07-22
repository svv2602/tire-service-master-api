class CreateGoogleOauthSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :google_oauth_settings do |t|
      t.string :client_id
      t.string :client_secret
      t.string :redirect_uri
      t.boolean :enabled, default: false, null: false
      t.boolean :allow_registration, default: true, null: false
      t.boolean :auto_verify_email, default: true, null: false
      t.text :scopes_list, default: 'email,profile'

      t.timestamps
    end
    
    # Создаем запись по умолчанию
    reversible do |dir|
      dir.up do
        GoogleOauthSetting.create!(
          enabled: false,
          allow_registration: true,
          auto_verify_email: true,
          scopes_list: 'email,profile',
          redirect_uri: 'http://localhost:3008/auth/google/callback'
        )
      end
    end
  end
end
