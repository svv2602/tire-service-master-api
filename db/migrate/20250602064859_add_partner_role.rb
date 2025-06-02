class AddPartnerRole < ActiveRecord::Migration[8.0]
  def up
    # Проверяем существует ли роль partner
    unless UserRole.exists?(name: 'partner')
      # Получаем следующий доступный ID
      next_id = UserRole.maximum(:id).to_i + 1
      
      UserRole.create!(
        id: next_id,
        name: 'partner',
        description: 'Роль партнера для управления сервисными точками',
        is_active: true
      )
      puts "Роль партнера успешно создана с ID: #{next_id}"
    else
      puts "Роль партнера уже существует"
    end
  end

  def down
    # При откате удаляем роль partner
    partner_role = UserRole.find_by(name: 'partner')
    if partner_role
      partner_role.destroy
      puts "Роль партнера удалена"
    end
  end
end
