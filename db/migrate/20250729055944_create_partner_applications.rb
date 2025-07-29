class CreatePartnerApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :partner_applications do |t|
      # Основная информация о компании
      t.string :company_name, null: false
      t.text :business_description, null: false
      t.string :contact_person, null: false
      t.string :email, null: false
      t.string :phone, null: false
      
      # Адрес и локация
      t.string :city, null: false
      t.string :address
      t.references :region, foreign_key: true, null: true
      t.references :city_record, foreign_key: { to_table: :cities }, null: true
      
      # Дополнительная информация
      t.string :website
      t.text :additional_info
      t.integer :expected_service_points, default: 1, null: false
      
      # Статус и обработка заявки
      t.string :status, default: 'new', null: false
      t.references :processed_by, foreign_key: { to_table: :users }, null: true
      t.text :admin_notes
      t.datetime :processed_at
      
      t.timestamps
    end

    # Индексы для оптимизации запросов
    add_index :partner_applications, :status
    add_index :partner_applications, :email
    add_index :partner_applications, :created_at
    add_index :partner_applications, :company_name
  end
end
