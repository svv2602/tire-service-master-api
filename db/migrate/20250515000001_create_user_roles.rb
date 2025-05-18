class CreateUserRoles < ActiveRecord::Migration[8.0]
  def change
    create_table :user_roles do |t|
      t.string :name, null: false, index: { unique: true }
      t.text :description
      t.boolean :is_active, default: true
      t.timestamps
    end

    # Добавляем начальные данные для ролей
    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO user_roles (name, description, is_active, created_at, updated_at) VALUES
          ('administrator', 'Administrators of the system', true, NOW(), NOW()),
          ('partner', 'Business owners providing tire services', true, NOW(), NOW()),
          ('manager', 'Employees of the partners managing service points', true, NOW(), NOW()),
          ('client', 'End users booking tire services', true, NOW(), NOW());
        SQL
      end
    end
  end
end
