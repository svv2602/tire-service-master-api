# Очистка базы данных перед запуском тестов для предотвращения конфликтов имен
# Особенно важно для тестов с уникальными именами, например, BookingStatus
RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
    
    # Создаем необходимые начальные статусы для тестов
    %w[pending confirmed in_progress completed canceled_by_client canceled_by_partner no_show].each_with_index do |name, index|
      BookingStatus.find_or_create_by(name: name) do |status|
        status.description = "Status #{name}"
        status.color = "#FFFFFF"
        status.sort_order = index + 1
      end
    end
    
    %w[pending paid failed refunded].each_with_index do |name, index|
      PaymentStatus.find_or_create_by(name: name) do |status|
        status.description = "Payment status #{name}"
        status.color = "#FFFFFF"
        status.sort_order = index + 1
      end
    end
  end
end
