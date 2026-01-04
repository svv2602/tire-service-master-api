class AddSupplierRoleAndLinkUserToSupplier < ActiveRecord::Migration[8.0]
  def up
    # Add supplier role
    execute <<-SQL
      INSERT INTO user_roles (name, description, is_active, created_at, updated_at)
      VALUES ('supplier', 'Поставщик шин', true, NOW(), NOW())
      ON CONFLICT (name) DO NOTHING;
    SQL

    # Add user_id to suppliers table
    unless column_exists?(:suppliers, :user_id)
      add_reference :suppliers, :user, null: true, foreign_key: true, index: true
    end
  end

  def down
    # Remove user_id from suppliers
    if column_exists?(:suppliers, :user_id)
      remove_reference :suppliers, :user
    end

    # Remove supplier role (be careful with this in production)
    execute <<-SQL
      DELETE FROM user_roles WHERE name = 'supplier'
      AND NOT EXISTS (SELECT 1 FROM users WHERE role_id = user_roles.id);
    SQL
  end
end
