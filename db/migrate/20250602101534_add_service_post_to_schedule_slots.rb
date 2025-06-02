class AddServicePostToScheduleSlots < ActiveRecord::Migration[8.0]
  def up
    # Добавляем поле как nullable сначала
    add_reference :schedule_slots, :service_post, null: true, foreign_key: true
    
    # Заполняем существующие записи
    populate_service_post_ids
    
    # Делаем поле обязательным
    change_column_null :schedule_slots, :service_post_id, false
  end
  
  def down
    remove_reference :schedule_slots, :service_post, foreign_key: true
  end
  
  private
  
  def populate_service_post_ids
    # Для каждого слота находим соответствующий service_post по номеру поста
    ScheduleSlot.includes(:service_point).find_each do |slot|
      service_post = slot.service_point.service_posts.find_by(post_number: slot.post_number)
      
      if service_post
        slot.update_column(:service_post_id, service_post.id)
      else
        # Если пост не найден, создаем его с настройками по умолчанию
        service_post = slot.service_point.service_posts.create!(
          post_number: slot.post_number,
          name: "Пост #{slot.post_number}",
          slot_duration: slot.service_point.default_slot_duration || 60,
          is_active: true,
          description: "Автоматически созданный пост при миграции"
        )
        slot.update_column(:service_post_id, service_post.id)
      end
    end
  end
end
