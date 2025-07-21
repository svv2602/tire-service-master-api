class CreateUserSocialAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :user_social_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :provider_user_id, null: false

      t.timestamps
    end

    # Уникальный индекс для предотвращения дублирования аккаунтов
    add_index :user_social_accounts, [:provider, :provider_user_id], unique: true, name: 'index_user_social_accounts_on_provider_and_provider_user_id'
  end
end
