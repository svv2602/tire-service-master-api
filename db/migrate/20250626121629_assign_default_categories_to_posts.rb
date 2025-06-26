class AssignDefaultCategoriesToPosts < ActiveRecord::Migration[8.0]
  def up
    # Создаем дефолтную категорию "Общие услуги" если её нет
    default_category = ServiceCategory.find_or_create_by!(
      name: 'Общие услуги',
      description: 'Универсальная категория для постов без специализации',
      is_active: true,
      sort_order: 999
    )
    
    # Назначаем всем постам без категории дефолтную категорию
    ServicePost.where(service_category_id: nil).update_all(
      service_category_id: default_category.id
    )
  end
  
  def down
    # Откат: убираем назначения
    ServicePost.where(service_category_id: ServiceCategory.find_by(name: 'Общие услуги')&.id)
               .update_all(service_category_id: nil)
  end
end
