class AddAutoConfirmationToServicePoints < ActiveRecord::Migration[8.0]
  def change
    add_column :service_points, :auto_confirmation, :boolean, default: false, null: false, comment: 'Автоматическое подтверждение бронирований (true) или ручное (false)'
    
    # Добавляем индекс для быстрого поиска точек с автоподтверждением
    add_index :service_points, :auto_confirmation
  end
end
