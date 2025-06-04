class AddCustomScheduleToServicePosts < ActiveRecord::Migration[8.0]
  def change
    # Флаг использования индивидуального расписания
    add_column :service_posts, :has_custom_schedule, :boolean, default: false, null: false, 
               comment: 'Использует ли пост индивидуальное расписание'
    
    # JSON с рабочими днями поста
    add_column :service_posts, :working_days, :json,
               comment: 'JSON с настройками рабочих дней поста (monday, tuesday, etc.)'
    
    # JSON с индивидуальными часами работы
    add_column :service_posts, :custom_hours, :json,
               comment: 'JSON с индивидуальным временем работы поста (start, end)'
  end
end
