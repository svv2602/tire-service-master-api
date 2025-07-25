class AddPerformanceIndexesForDataIsolation < ActiveRecord::Migration[8.0]
  def change
    # Индексы для изоляции данных партнеров
    add_index :service_points, [:partner_id, :is_active], name: 'idx_service_points_partner_active'
    add_index :service_points, [:partner_id, :city_id], name: 'idx_service_points_partner_city'
    
    # Индексы для операторов и их привязки к точкам
    add_index :operator_service_points, [:operator_id, :service_point_id], name: 'idx_operator_service_points_operator_point', unique: true
    add_index :operator_service_points, [:service_point_id, :is_active], name: 'idx_operator_service_points_point_active'
    
    # Индексы для бронирований с изоляцией
    add_index :bookings, [:service_point_id, :booking_date], name: 'idx_bookings_point_date'
    add_index :bookings, [:client_id, :status, :booking_date], name: 'idx_bookings_client_status_date'
    add_index :bookings, [:service_point_id, :status], name: 'idx_bookings_point_status'
    
    # Индексы для отзывов с изоляцией
    add_index :reviews, [:service_point_id, :is_published], name: 'idx_reviews_point_published'
    add_index :reviews, [:client_id, :created_at], name: 'idx_reviews_client_created'
    
    # Индексы для системы ролей
    add_index :users, [:role_id, :is_active], name: 'idx_users_role_active'
    add_index :user_roles, [:name, :is_active], name: 'idx_user_roles_name_active'
    
    # Индексы для аудита с производительностью
    add_index :system_logs, [:user_id, :created_at], name: 'idx_system_logs_user_created'
    add_index :system_logs, [:resource_type, :resource_id, :created_at], name: 'idx_system_logs_resource_created'
    add_index :system_logs, [:ip_address, :created_at], name: 'idx_system_logs_ip_created'
    add_index :system_logs, [:action, :created_at], name: 'idx_system_logs_action_created'
    
    # Составные индексы для сложных запросов
    add_index :service_points, [:partner_id, :is_active, :city_id, :created_at], name: 'idx_service_points_complex_filter'
    add_index :bookings, [:service_point_id, :status, :booking_date, :start_time], name: 'idx_bookings_complex_filter'
    
    # Индексы для производительности middleware
    add_index :users, [:id, :is_active], name: 'idx_users_id_active'
    add_index :partners, [:id, :is_active], name: 'idx_partners_id_active'
    
    # Индексы для полнотекстового поиска (если используется PostgreSQL)
    if connection.adapter_name.downcase.include?('postgresql')
      # GIN индексы для JSONB полей
      add_index :system_logs, :additional_data, using: :gin, name: 'idx_system_logs_additional_data_gin'
      add_index :system_logs, :changes, using: :gin, name: 'idx_system_logs_changes_gin'
      
      # Индексы для текстового поиска (без CONCURRENTLY в миграции)
      execute <<-SQL
        CREATE INDEX IF NOT EXISTS idx_service_points_search_text 
        ON service_points USING gin(to_tsvector('russian', name || ' ' || COALESCE(description, '')));
      SQL
      
      execute <<-SQL
        CREATE INDEX IF NOT EXISTS idx_reviews_search_text 
        ON reviews USING gin(to_tsvector('russian', COALESCE(comment, '')));
      SQL
    end
  end
  
  def down
    # Удаляем индексы в обратном порядке
    remove_index :service_points, name: 'idx_service_points_partner_active' if index_exists?(:service_points, name: 'idx_service_points_partner_active')
    remove_index :service_points, name: 'idx_service_points_partner_city' if index_exists?(:service_points, name: 'idx_service_points_partner_city')
    
    remove_index :operator_service_points, name: 'idx_operator_service_points_operator_point' if index_exists?(:operator_service_points, name: 'idx_operator_service_points_operator_point')
    remove_index :operator_service_points, name: 'idx_operator_service_points_point_active' if index_exists?(:operator_service_points, name: 'idx_operator_service_points_point_active')
    
    remove_index :bookings, name: 'idx_bookings_point_date' if index_exists?(:bookings, name: 'idx_bookings_point_date')
    remove_index :bookings, name: 'idx_bookings_client_status_date' if index_exists?(:bookings, name: 'idx_bookings_client_status_date')
    remove_index :bookings, name: 'idx_bookings_point_status' if index_exists?(:bookings, name: 'idx_bookings_point_status')
    
    remove_index :reviews, name: 'idx_reviews_point_published' if index_exists?(:reviews, name: 'idx_reviews_point_published')
    remove_index :reviews, name: 'idx_reviews_client_created' if index_exists?(:reviews, name: 'idx_reviews_client_created')
    
    remove_index :users, name: 'idx_users_role_active' if index_exists?(:users, name: 'idx_users_role_active')
    remove_index :user_roles, name: 'idx_user_roles_name_active' if index_exists?(:user_roles, name: 'idx_user_roles_name_active')
    
    remove_index :system_logs, name: 'idx_system_logs_user_created' if index_exists?(:system_logs, name: 'idx_system_logs_user_created')
    remove_index :system_logs, name: 'idx_system_logs_resource_created' if index_exists?(:system_logs, name: 'idx_system_logs_resource_created')
    remove_index :system_logs, name: 'idx_system_logs_ip_created' if index_exists?(:system_logs, name: 'idx_system_logs_ip_created')
    remove_index :system_logs, name: 'idx_system_logs_action_created' if index_exists?(:system_logs, name: 'idx_system_logs_action_created')
    
    remove_index :service_points, name: 'idx_service_points_complex_filter' if index_exists?(:service_points, name: 'idx_service_points_complex_filter')
    remove_index :bookings, name: 'idx_bookings_complex_filter' if index_exists?(:bookings, name: 'idx_bookings_complex_filter')
    
    remove_index :users, name: 'idx_users_id_active' if index_exists?(:users, name: 'idx_users_id_active')
    remove_index :partners, name: 'idx_partners_id_active' if index_exists?(:partners, name: 'idx_partners_id_active')
    
    if connection.adapter_name.downcase.include?('postgresql')
      remove_index :system_logs, name: 'idx_system_logs_additional_data_gin' if index_exists?(:system_logs, name: 'idx_system_logs_additional_data_gin')
      remove_index :system_logs, name: 'idx_system_logs_changes_gin' if index_exists?(:system_logs, name: 'idx_system_logs_changes_gin')
      
      execute 'DROP INDEX IF EXISTS idx_service_points_search_text;'
      execute 'DROP INDEX IF EXISTS idx_reviews_search_text;'
    end
  end
end
