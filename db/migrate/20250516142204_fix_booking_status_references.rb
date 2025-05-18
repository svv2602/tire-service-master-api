class FixBookingStatusReferences < ActiveRecord::Migration[8.0]
  def change
    # Убедимся, что все необходимые статусы существуют
    reversible do |dir|
      dir.up do
        # Создаем статусы бронирования, если их еще нет
        pending = BookingStatus.find_or_create_by!(name: 'pending') do |status|
          status.description = 'Booking has been created but not confirmed'
          status.color = '#FFC107'
          status.sort_order = 1
          status.is_active = true
        end
        
        payment_pending = PaymentStatus.find_or_create_by!(name: 'pending') do |status|
          status.description = 'Payment is pending'
          status.color = '#FFC107'
          status.sort_order = 1
          status.is_active = true
        end
        
        puts "Created booking status: #{pending.inspect}"
        puts "Created payment status: #{payment_pending.inspect}"
      end
    end
    
    # Временно отключаем ограничения внешнего ключа для поля status_id
    remove_foreign_key :bookings, :booking_statuses, column: :status_id, if_exists: true
    
    # Изменяем колонку status_id на integer без ограничений на null
    change_column :bookings, :status_id, :integer, null: true
    
    # Добавляем индекс для оптимизации поиска
    add_index :bookings, :status_id, if_not_exists: true
    
    # Аналогично для payment_status_id
    remove_foreign_key :bookings, :payment_statuses, column: :payment_status_id, if_exists: true
    change_column :bookings, :payment_status_id, :integer, null: true
    add_index :bookings, :payment_status_id, if_not_exists: true
    
    # Добавляем внешний ключ с опцией validate: false, чтобы избежать проверки существующих записей
    add_foreign_key :bookings, :booking_statuses, column: :status_id, validate: false, on_delete: :restrict
    add_foreign_key :bookings, :payment_statuses, column: :payment_status_id, validate: false, on_delete: :restrict
  end
end
