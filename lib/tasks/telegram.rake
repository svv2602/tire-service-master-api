namespace :telegram do
  desc "Встановити webhook для Telegram бота"
  task set_webhook: :environment do
    webhook_url = ENV['TELEGRAM_WEBHOOK_URL']
    
    if webhook_url.blank?
      puts "❌ TELEGRAM_WEBHOOK_URL не установлен в переменных окружения"
      exit 1
    end
    
    begin
      telegram_service = TelegramService.new
      response = telegram_service.set_webhook(webhook_url)
      
      if response[:ok]
        puts "✅ Webhook установлен успешно: #{webhook_url}"
        puts "📋 Описание: #{response[:description]}"
      else
        puts "❌ Ошибка установки webhook: #{response[:description]}"
        exit 1
      end
    rescue => e
      puts "❌ Исключение при установке webhook: #{e.message}"
      exit 1
    end
  end

  desc "Удалить webhook Telegram бота"
  task delete_webhook: :environment do
    begin
      telegram_service = TelegramService.new
      response = telegram_service.delete_webhook
      
      if response[:ok]
        puts "✅ Webhook удален успешно"
        puts "📋 Описание: #{response[:description]}"
      else
        puts "❌ Ошибка удаления webhook: #{response[:description]}"
      end
    rescue => e
      puts "❌ Исключение при удалении webhook: #{e.message}"
    end
  end

  desc "Получить информацию о webhook"
  task webhook_info: :environment do
    begin
      telegram_service = TelegramService.new
      response = telegram_service.get_webhook_info
      
      if response[:ok]
        info = response[:result]
        puts "📋 Информация о webhook:"
        puts "URL: #{info[:url] || 'не установлен'}"
        puts "Последняя ошибка: #{info[:last_error_message] || 'нет'}"
        puts "Дата последней ошибки: #{info[:last_error_date] || 'нет'}"
        puts "Максимальное количество подключений: #{info[:max_connections] || 'не указано'}"
        puts "Разрешенные обновления: #{info[:allowed_updates]&.join(', ') || 'все'}"
        puts "Количество ожидающих обновлений: #{info[:pending_update_count] || 0}"
      else
        puts "❌ Ошибка получения информации: #{response[:description]}"
      end
    rescue => e
      puts "❌ Исключение при получении информации: #{e.message}"
    end
  end

  desc "Отправить тестовое сообщение"
  task :test_message, [:chat_id, :message] => :environment do |t, args|
    chat_id = args[:chat_id]
    message = args[:message] || "Тестовое сообщение от Tire Service"
    
    if chat_id.blank?
      puts "❌ Использование: rails telegram:test_message[chat_id,message]"
      exit 1
    end
    
    begin
      telegram_service = TelegramService.new
      response = telegram_service.send_message(chat_id, message)
      
      if response[:ok]
        puts "✅ Сообщение отправлено успешно"
        puts "📋 Message ID: #{response[:result][:message_id]}"
      else
        puts "❌ Ошибка отправки: #{response[:description]}"
      end
    rescue => e
      puts "❌ Исключение при отправке: #{e.message}"
    end
  end

  desc "Получить обновления (для тестирования без webhook)"
  task get_updates: :environment do
    begin
      telegram_service = TelegramService.new
      response = telegram_service.get_updates
      
      if response[:ok]
        updates = response[:result]
        puts "📋 Получено обновлений: #{updates.length}"
        
        updates.each do |update|
          puts "Update ID: #{update[:update_id]}"
          
          if update[:message]
            message = update[:message]
            puts "  Сообщение от #{message[:from][:first_name]} (#{message[:chat][:id]}): #{message[:text]}"
          end
          
          if update[:callback_query]
            callback = update[:callback_query]
            puts "  Callback от #{callback[:from][:first_name]}: #{callback[:data]}"
          end
          
          puts "---"
        end
      else
        puts "❌ Ошибка получения обновлений: #{response[:description]}"
      end
    rescue => e
      puts "❌ Исключение при получении обновлений: #{e.message}"
    end
  end

  desc "Статистика Telegram уведомлений"
  task stats: :environment do
    puts "📊 Статистика Telegram уведомлений:"
    puts "="*50
    
    total_subscriptions = TelegramSubscription.count
    active_subscriptions = TelegramSubscription.active.count
    blocked_subscriptions = TelegramSubscription.blocked.count
    
    puts "📱 Подписки:"
    puts "  Всего: #{total_subscriptions}"
    puts "  Активных: #{active_subscriptions}"
    puts "  Заблокированных: #{blocked_subscriptions}"
    puts ""
    
    total_notifications = TelegramNotification.count
    sent_notifications = TelegramNotification.sent.count
    failed_notifications = TelegramNotification.failed.count
    pending_notifications = TelegramNotification.pending.count
    
    puts "📨 Уведомления:"
    puts "  Всего: #{total_notifications}"
    puts "  Отправлено: #{sent_notifications}"
    puts "  Неудачных: #{failed_notifications}"
    puts "  Ожидающих: #{pending_notifications}"
    
    if total_notifications > 0
      success_rate = (sent_notifications.to_f / total_notifications * 100).round(2)
      puts "  Успешность: #{success_rate}%"
    end
    
    puts ""
    
    # Статистика по типам
    puts "📋 По типам уведомлений:"
    TelegramNotification.group(:notification_type).count.each do |type, count|
      puts "  #{type}: #{count}"
    end
    
    puts ""
    
    # Последние уведомления
    puts "📝 Последние 5 уведомлений:"
    TelegramNotification.recent.limit(5).each do |notification|
      status_emoji = case notification.status
                     when 'sent' then '✅'
                     when 'failed' then '❌'
                     else '⏳'
                     end
      
      puts "  #{status_emoji} #{notification.notification_type} - #{notification.message.truncate(50)} (#{notification.created_at.strftime('%d.%m.%Y %H:%M')})"
    end
  end

  desc "Повторить неудачные уведомления"
  task retry_failed: :environment do
    telegram_service = TelegramService.new
    retried_count = telegram_service.retry_failed_notifications
    
    puts "🔄 Повторно отправлено уведомлений: #{retried_count}"
  end

  desc "Очистить старые уведомления"
  task :cleanup, [:days] => :environment do |t, args|
    days = args[:days]&.to_i || 30
    
    old_notifications = TelegramNotification.where('created_at < ?', days.days.ago)
    count = old_notifications.count
    
    if count > 0
      old_notifications.destroy_all
      puts "🗑️ Удалено старых уведомлений: #{count} (старше #{days} дней)"
    else
      puts "✅ Нет старых уведомлений для удаления"
    end
  end

  desc "Экспорт подписок в CSV"
  task export_subscriptions: :environment do
    require 'csv'
    
    filename = "telegram_subscriptions_#{Date.current.strftime('%Y%m%d')}.csv"
    filepath = Rails.root.join('tmp', filename)
    
    CSV.open(filepath, 'w', headers: true) do |csv|
      csv << ['ID', 'User ID', 'Chat ID', 'Username', 'Full Name', 'Language', 'Status', 'Created At', 'Last Interaction']
      
      TelegramSubscription.includes(:user).each do |subscription|
        csv << [
          subscription.id,
          subscription.user_id,
          subscription.chat_id,
          subscription.username,
          subscription.full_name,
          subscription.language_code,
          subscription.status,
          subscription.created_at.strftime('%Y-%m-%d %H:%M:%S'),
          subscription.last_interaction_at&.strftime('%Y-%m-%d %H:%M:%S')
        ]
      end
    end
    
    puts "📊 Экспорт завершен: #{filepath}"
    puts "📋 Экспортировано подписок: #{TelegramSubscription.count}"
  end

  desc "Настройка бота (установка webhook и команд)"
  task setup: :environment do
    puts "🚀 Настройка Telegram бота..."
    
    # Устанавливаем webhook
    Rake::Task['telegram:set_webhook'].invoke
    
    # Устанавливаем команды бота
    begin
      telegram_service = TelegramService.new
      
      commands = [
        { command: 'start', description: 'Начать работу с ботом' },
        { command: 'help', description: 'Получить справку' },
        { command: 'status', description: 'Статус подписки' },
        { command: 'settings', description: 'Настройки уведомлений' },
        { command: 'stop', description: 'Остановить уведомления' }
      ]
      
      response = telegram_service.class.post(
        "/bot#{ENV['TELEGRAM_BOT_TOKEN']}/setMyCommands",
        body: { commands: commands.to_json },
        headers: { 'Content-Type' => 'application/json' }
      )
      
      if response.code == 200
        puts "✅ Команды бота установлены"
      else
        puts "⚠️ Не удалось установить команды бота"
      end
    rescue => e
      puts "❌ Ошибка установки команд: #{e.message}"
    end
    
    puts "🎉 Настройка завершена!"
  end
end 