class AddOpenSslVerifyModeToEmailSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :email_settings, :openssl_verify_mode, :string, default: 'none'
    
    # Обновляем существующие записи
    reversible do |dir|
      dir.up do
        EmailSetting.update_all(openssl_verify_mode: 'none')
      end
    end
  end
end
