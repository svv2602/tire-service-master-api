# Базовый класс для всех сервисов в приложении
# Предоставляет общие методы и интерфейс
class ApplicationService
  # Позволяет вызывать сервис через ClassName.call(args)
  def self.call(*args, &block)
    new(*args, &block).call
  end

  private

  # Определяем базовый метод call, который должен быть переопределен в наследниках
  def call
    raise NotImplementedError, "#{self.class} должен реализовать метод #call"
  end

  # Вспомогательный метод для логирования
  def log_info(message)
    Rails.logger.info "[#{self.class.name}] #{message}"
  end

  def log_error(message)
    Rails.logger.error "[#{self.class.name}] #{message}"
  end

  # Вспомогательный метод для обработки ошибок
  def handle_error(error, context = nil)
    log_error "Ошибка: #{error.message}#{context ? " (контекст: #{context})" : ""}"
    raise error
  end
end 