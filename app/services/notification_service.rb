# frozen_string_literal: true

# NotificationService - backward-compatible facade
# Делегирует вызовы к модульной архитектуре Notifications::Service
#
# Новый код должен использовать напрямую:
# - Notifications::Service - оркестратор
# - Notifications::ChannelRouter - выбор каналов
# - Notifications::TemplateRenderer - рендеринг шаблонов
# - Notifications::DeliveryManager - доставка уведомлений
class NotificationService
  # Константы для типов уведомлений (для обратной совместимости)
  NOTIFICATION_TYPES = Notifications::Service::NOTIFICATION_TYPES

  class << self
    # Основной метод для создания и отправки уведомления
    def send_notification(recipient, type_name, data = {})
      service.send_notification(recipient, type_name, data)
    end

    # Создание уведомления о бронировании
    def booking_notification(booking, type, additional_data = {})
      service.booking_notification(booking, type, additional_data)
    end

    # Системные уведомления
    def system_notification(recipients, title, message, priority: 'normal', category: 'system')
      service.system_notification(recipients, title, message, priority: priority, category: category)
    end

    # Методы для конкретных типов уведомлений
    def send_booking_created(booking, data = {})
      service.booking_notification(booking, :created, data)
    end

    def send_booking_confirmed(booking, data = {})
      service.booking_notification(booking, :confirmed, data)
    end

    def send_booking_cancelled(booking, data = {})
      service.booking_notification(booking, :cancelled, data)
    end

    def send_booking_reminder(booking, data = {})
      service.booking_notification(booking, :reminder, data)
    end

    def send_booking_completed(booking, data = {})
      service.booking_notification(booking, :completed, data)
    end

    # Строит переменные для бронирования
    def build_booking_variables(booking)
      service.template_renderer.build_booking_variables(booking)
    end

    # Уведомления для операторов (делегирование через instance методы)
    def send_operator_assignment_notification(operator, service_point, action_type)
      new.send_operator_assignment_notification(operator, service_point, action_type)
    end

    def send_partner_operator_notification(partner, operator, action_type)
      new.send_partner_operator_notification(partner, operator, action_type)
    end

    private

    def service
      @service ||= Notifications::Service.new
    end
  end

  def initialize
    @service = Notifications::Service.new
  end

  def send_operator_assignment_notification(operator, service_point, action_type)
    @service.send_operator_assignment_notification(operator, service_point, action_type)
  end

  def send_partner_operator_notification(partner, operator, action_type)
    @service.send_partner_operator_notification(partner, operator, action_type)
  end

  # Доступ к внутренним сервисам
  def channel_router
    @service.channel_router
  end

  def template_renderer
    @service.template_renderer
  end

  def delivery_manager
    @service.delivery_manager
  end
end
