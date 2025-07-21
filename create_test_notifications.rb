# Создаем тестовые уведомления для админа
admin_user = User.find_by(email: 'admin@test.com')
if admin_user
  notification_type = NotificationType.first || NotificationType.create!(
    name: 'test_notification',
    template: 'Test notification template',
    is_push: true,
    is_email: false,
    is_sms: false
  )
  
  # Создаем несколько уведомлений с разными приоритетами и категориями
  [
    { title: 'Системное уведомление', message: 'Система обновлена', priority: 'high', category: 'system' },
    { title: 'Новое бронирование', message: 'Получено новое бронирование', priority: 'normal', category: 'booking' },
    { title: 'Акция', message: 'Новая акция на услуги', priority: 'low', category: 'promotion' }
  ].each do |attrs|
    Notification.create!(
      notification_type: notification_type,
      recipient_type: 'User',
      recipient_id: admin_user.id,
      title: attrs[:title],
      message: attrs[:message],
      send_via: 'push',
      priority: attrs[:priority],
      category: attrs[:category]
    )
  end
  
  puts "Созданы тестовые уведомления для пользователя: #{admin_user.email}"
  puts "Всего уведомлений: #{Notification.count}"
else
  puts 'Админ не найден'
end 