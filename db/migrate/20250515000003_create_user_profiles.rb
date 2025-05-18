class CreateUserProfiles < ActiveRecord::Migration[8.0]
  def change
    # Таблица администраторов
    create_table :administrators do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :position
      t.integer :access_level, default: 1
      t.timestamps
    end

    # Таблица партнеров
    create_table :partners do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :company_name, null: false, index: true
      t.text :company_description
      t.string :contact_person
      t.string :logo_url
      t.string :website
      t.string :tax_number
      t.text :legal_address
      t.timestamps
    end

    # Таблица клиентов
    create_table :clients do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :preferred_notification_method, default: 'push'
      t.boolean :marketing_consent, default: false
      t.timestamps
    end

    # Таблица менеджеров
    create_table :managers do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.references :partner, null: false, foreign_key: true
      t.integer :access_level, default: 1
      t.timestamps
    end
  end
end
