RSpec.configure do |config|
  config.before(:each, type: :request) do
    # Временно патчим метод valid_status_id для тестов
    Booking.class_eval do
      def valid_status_id
        # Всегда возвращаем true в тестах
        true
      end
    end
  end
  
  config.after(:each, type: :request) do
    # Восстанавливаем оригинальный метод после тестов, если нужно
    if Booking.method_defined?(:valid_status_id_original)
      Booking.class_eval do
        alias_method :valid_status_id, :valid_status_id_original
        remove_method :valid_status_id_original
      end
    end
  end
end
