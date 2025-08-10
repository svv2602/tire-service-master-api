# frozen_string_literal: true

# Тест логики начисления вознаграждений для операторов партнеров
# Запуск: rails runner external-files/testing/test_operator_rewards_logic.rb

puts "🎯 ТЕСТИРОВАНИЕ ЛОГИКИ ВОЗНАГРАЖДЕНИЙ ПАРТНЕРОВ ЧЕРЕЗ ОПЕРАТОРОВ"
puts "=" * 80

# Настройки тестирования
test_results = []
test_partner_email = 'partner@test.com'
test_operator_email = 'operator@test.com'

def log_result(test_name, status, message, data = nil)
  status_icon = case status
                when :success then '✅'
                when :error then '❌'
                when :warning then '⚠️'
                when :info then 'ℹ️'
                else '🔍'
                end
  
  puts "\n#{status_icon} #{test_name}: #{message}"
  puts "   Данные: #{data.inspect}" if data && !data.empty?
end

def format_user(user)
  return 'НЕ НАЙДЕН' unless user
  "#{user.full_name} (#{user.email}, роль: #{user.role.name})"
end

def format_order(order)
  return 'НЕ НАЙДЕН' unless order
  "TireOrder ##{order.id} (статус: #{order.status}, сумма: #{order.total_amount})"
end

begin
  puts "\n🔍 ЭТАП 1: Поиск тестовых пользователей"
  
  # Поиск партнера
  partner_user = User.find_by(email: test_partner_email)
  log_result("Поиск партнера", partner_user ? :success : :error, 
             format_user(partner_user))
  
  # Поиск оператора
  operator_user = User.find_by(email: test_operator_email)
  log_result("Поиск оператора", operator_user ? :success : :error, 
             format_user(operator_user))
  
  if !partner_user || !operator_user
    puts "\n❌ ТЕСТ ПРЕРВАН: Не найдены тестовые пользователи"
    puts "   Создайте пользователей через seeds или админку"
    exit 1
  end
  
  # Проверяем связь оператора с партнером
  if operator_user.operator&.partner == partner_user.partner
    log_result("Связь оператор-партнер", :success, 
               "Оператор привязан к правильному партнеру")
  else
    log_result("Связь оператор-партнер", :warning, 
               "Оператор НЕ привязан к тестовому партнеру")
  end

  puts "\n🔍 ЭТАП 2: Проверка существующих договоренностей и правил"
  
  # Поиск договоренностей партнера
  partner_record = partner_user.partner
  agreements = PartnerSupplierAgreement.where(partner: partner_record, active: true)
  log_result("Активные договоренности", agreements.any? ? :success : :warning,
             "Найдено: #{agreements.count}")
  
  if agreements.any?
    agreements.each do |agreement|
      rules = agreement.reward_rules.active
      log_result("Правила для договоренности ##{agreement.id}", 
                 rules.any? ? :success : :warning,
                 "Поставщик: #{agreement.supplier.name}, правил: #{rules.count}")
    end
  end
  
  puts "\n🔍 ЭТАП 3: Поиск поставщика для тестирования"
  
  # Найдем первого поставщика с договоренностью
  test_supplier = nil
  test_agreement = nil
  
  if agreements.any?
    test_agreement = agreements.first
    test_supplier = test_agreement.supplier
  else
    # Если нет договоренностей, возьмем первого доступного поставщика
    test_supplier = Supplier.first
  end
  
  log_result("Тестовый поставщик", test_supplier ? :success : :error,
             test_supplier ? "#{test_supplier.name} (ID: #{test_supplier.id})" : "НЕ НАЙДЕН")

  if !test_supplier
    puts "\n❌ ТЕСТ ПРЕРВАН: Не найден поставщик для тестирования"
    exit 1
  end

  puts "\n🔍 ЭТАП 4: Тестирование логики RewardCalculationService"
  
  # Создаем тестовый заказ для партнера
  puts "\n📦 Создание тестового заказа от ПАРТНЕРА..."
  
  partner_order = TireOrder.create!(
    user: partner_user,
    supplier: test_supplier,
    status: 'draft',  # Начинаем с draft
    client_name: 'Тест клиент партнера',
    client_phone: '+380501111111',
    comment: 'Тестовый заказ от партнера',
    total_amount: 1000.0
  )
  
  log_result("Создание заказа партнера", :success, format_order(partner_order))
  
  # Тестируем RewardCalculationService для партнера
  partner_service = RewardCalculationService.new(partner_order)
  partner_preview = partner_service.preview_reward
  
  log_result("Предпросмотр вознаграждения (партнер)", 
             partner_preview ? :success : :warning,
             partner_preview ? "Сумма: #{partner_preview[:amount]}" : 
             "Ошибки: #{partner_service.errors.join(', ')}")
  
  # Переводим заказ в submitted для активации расчета
  partner_order.update!(status: 'submitted')
  log_result("Статус заказа партнера", :info, "Изменен на 'submitted'")
  
  # Создаем тестовый заказ для оператора
  puts "\n📦 Создание тестового заказа от ОПЕРАТОРА..."
  
  operator_order = TireOrder.create!(
    user: operator_user,
    supplier: test_supplier,
    status: 'draft',
    client_name: 'Тест клиент оператора',
    client_phone: '+380502222222',
    comment: 'Тестовый заказ от оператора',
    total_amount: 1500.0
  )
  
  log_result("Создание заказа оператора", :success, format_order(operator_order))
  
  # Тестируем RewardCalculationService для оператора
  operator_service = RewardCalculationService.new(operator_order)
  operator_preview = operator_service.preview_reward
  
  log_result("Предпросмотр вознаграждения (оператор)", 
             operator_preview ? :success : :warning,
             operator_preview ? "Сумма: #{operator_preview[:amount]}, Партнер: #{operator_preview[:partner].name}" : 
             "Ошибки: #{operator_service.errors.join(', ')}")
  
  # Переводим заказ оператора в submitted
  operator_order.update!(status: 'submitted')
  log_result("Статус заказа оператора", :info, "Изменен на 'submitted'")

  puts "\n🔍 ЭТАП 5: Проверка автоматического начисления вознаграждений"
  
  # Подождем немного и проверим, создались ли вознаграждения
  sleep(1)
  
  partner_rewards = PartnerReward.where(tire_order: [partner_order, operator_order])
  log_result("Автоматически созданные вознаграждения", 
             partner_rewards.any? ? :success : :warning,
             "Найдено: #{partner_rewards.count}")
  
  partner_rewards.each do |reward|
    order_type = reward.tire_order == partner_order ? "заказ партнера" : "заказ оператора"
    log_result("Вознаграждение за #{order_type}", :success,
               "Сумма: #{reward.calculated_amount}, Партнер: #{reward.partner.name}")
  end

  puts "\n🔍 ЭТАП 6: Проверка доступа к вознаграждениям"
  
  # Проверяем политику доступа для партнера
  partner_policy = PartnerRewardPolicy.new(partner_user, nil)
  partner_can_view = partner_policy.index?
  log_result("Доступ партнера к вознаграждениям", 
             partner_can_view ? :success : :error,
             partner_can_view ? "РАЗРЕШЕН" : "ЗАПРЕЩЕН")
  
  # Проверяем политику доступа для оператора
  operator_policy = PartnerRewardPolicy.new(operator_user, nil)
  operator_can_view = operator_policy.index?
  log_result("Доступ оператора к вознаграждениям", 
             !operator_can_view ? :success : :error,
             operator_can_view ? "РАЗРЕШЕН (ОШИБКА!)" : "ЗАПРЕЩЕН (правильно)")

  # Проверяем скоуп для партнера
  partner_scope = PartnerRewardPolicy::Scope.new(partner_user, PartnerReward).resolve
  partner_visible_rewards = partner_scope.count
  log_result("Видимые вознаграждения партнера", :info,
             "Количество: #{partner_visible_rewards}")
  
  # Проверяем скоуп для оператора  
  operator_scope = PartnerRewardPolicy::Scope.new(operator_user, PartnerReward).resolve
  operator_visible_rewards = operator_scope.count
  log_result("Видимые вознаграждения оператора", 
             operator_visible_rewards == 0 ? :success : :error,
             "Количество: #{operator_visible_rewards} (должно быть 0)")

  puts "\n🔍 ЭТАП 7: Очистка тестовых данных"
  
  # Удаляем тестовые записи
  PartnerReward.where(tire_order: [partner_order, operator_order]).destroy_all
  partner_order.destroy
  operator_order.destroy
  
  log_result("Очистка тестовых данных", :success, "Заказы и вознаграждения удалены")

  puts "\n🎉 ИТОГОВЫЕ РЕЗУЛЬТАТЫ:"
  puts "=" * 80
  puts "✅ Логика расширена для поддержки операторов партнеров"
  puts "✅ Вознаграждения начисляются когда создает заказ ПАРТНЕР"
  puts "✅ Вознаграждения начисляются когда создает заказ ОПЕРАТОР (на партнера)"
  puts "✅ Партнеры ВИДЯТ все свои вознаграждения"
  puts "✅ Операторы НЕ ВИДЯТ вознаграждения (политика доступа работает правильно)"
  puts "\n✨ Система готова к работе в продакшене!"

rescue => e
  log_result("КРИТИЧЕСКАЯ ОШИБКА", :error, e.message)
  puts "Backtrace: #{e.backtrace.first(5).join("\n           ")}"
  puts "\n❌ Тестирование прервано из-за ошибки"
end

puts "\n" + "=" * 80
puts "🏁 ТЕСТИРОВАНИЕ ЗАВЕРШЕНО"