# frozen_string_literal: true

module Notifications
  # Service - главный оркестратор уведомлений
  # Отвечает за: координацию модулей, создание и отправку уведомлений
  class Service
    NOTIFICATION_TYPES = {
      booking_created: 'booking_created',
      booking_confirmed: 'booking_confirmed',
      booking_cancelled: 'booking_cancelled',
      booking_completed: 'booking_completed',
      booking_reminder: 'booking_reminder',
      system_notification: 'system_notification',
      payment_successful: 'payment_successful',
      review_request: 'review_request'
    }.freeze

    attr_reader :channel_router, :template_renderer, :delivery_manager

    def initialize(channel_router: nil, template_renderer: nil, delivery_manager: nil)
      @channel_router = channel_router || ChannelRouter.new
      @template_renderer = template_renderer || TemplateRenderer.new
      @delivery_manager = delivery_manager || DeliveryManager.new(channel_router: @channel_router)
    end

    # Основной метод для создания и отправки уведомления
    # @param recipient [User, Client] получатель
    # @param type_name [String] название типа уведомления
    # @param data [Hash] дополнительные данные
    # @return [Notification, false] созданное уведомление или false
    def send_notification(recipient, type_name, data = {})
      notification_type = NotificationType.find_by(name: type_name)
      return false unless notification_type&.is_active?

      notification_data = template_renderer.prepare_notification_data(recipient, notification_type, data)
      notification = create_notification(recipient, notification_type, notification_data, data)
      return false unless notification

      channels = channel_router.determine_channels(notification_type, data[:channels])
      delivery_manager.deliver(notification, channels, data)

      notification.mark_as_sent!
      notification
    end

    # Создание уведомления о бронировании
    # @param booking [Booking] бронирование
    # @param type [Symbol] тип (:created, :confirmed, :cancelled, :reminder, :completed)
    # @param additional_data [Hash] дополнительные данные
    def booking_notification(booking, type, additional_data = {})
      case type
      when :created
        send_booking_created(booking, additional_data)
      when :confirmed
        send_booking_confirmed(booking, additional_data)
      when :cancelled
        send_booking_cancelled(booking, additional_data)
      when :reminder
        send_booking_reminder(booking, additional_data)
      when :completed
        send_booking_completed(booking, additional_data)
      end
    end

    # Системные уведомления
    # @param recipients [User, Array<User>] получатели
    # @param title [String] заголовок
    # @param message [String] сообщение
    # @param priority [String] приоритет
    # @param category [String] категория
    def system_notification(recipients, title, message, priority: 'normal', category: 'system')
      recipients = [recipients] unless recipients.is_a?(Array)

      recipients.map do |recipient|
        send_notification(recipient, 'system_notification', {
          title: title,
          message: message,
          priority: priority,
          category: category,
          channels: %w[push email]
        })
      end
    end

    # === Уведомления для операторов ===

    def send_operator_assignment_notification(operator, service_point, action_type)
      return unless operator&.user&.email && service_point

      case action_type
      when 'assigned'
        send_operator_assigned(operator, service_point)
      when 'unassigned'
        send_operator_unassigned(operator, service_point)
      end
    end

    def send_partner_operator_notification(partner, operator, action_type)
      return unless partner&.user&.email && operator

      case action_type
      when 'operator_created'
        send_partner_new_operator(partner, operator)
      when 'operator_activated'
        send_partner_operator_activated(partner, operator)
      when 'operator_deactivated'
        send_partner_operator_deactivated(partner, operator)
      end
    end

    private

    # === Booking notifications ===

    def send_booking_created(booking, data)
      send_notification(booking.client, 'booking_created', {
        title: 'Бронювання створено',
        message: "Ваш запис на #{booking.booking_date} о #{booking.start_time} створено",
        category: 'booking',
        priority: 'normal',
        template_type: 'booking_confirmation',
        variables: template_renderer.build_booking_variables(booking),
        channels: %w[push email]
      }.merge(data))
    end

    def send_booking_confirmed(booking, data)
      send_notification(booking.client, 'booking_confirmed', {
        title: 'Бронювання підтверджено',
        message: "Ваш запис на #{booking.booking_date} о #{booking.start_time} підтверджено",
        category: 'booking',
        priority: 'high',
        template_type: 'booking_confirmation',
        variables: template_renderer.build_booking_variables(booking),
        channels: %w[push email sms]
      }.merge(data))
    end

    def send_booking_cancelled(booking, data)
      send_notification(booking.client, 'booking_cancelled', {
        title: 'Бронювання скасовано',
        message: "Ваш запис на #{booking.booking_date} о #{booking.start_time} скасовано",
        category: 'booking',
        priority: 'high',
        template_type: 'booking_cancelled',
        variables: template_renderer.build_booking_variables(booking),
        channels: %w[push email sms]
      }.merge(data))
    end

    def send_booking_reminder(booking, data)
      send_notification(booking.client, 'booking_reminder', {
        title: 'Нагадування про запис',
        message: "Нагадуємо про ваш запис завтра о #{booking.start_time}",
        category: 'reminder',
        priority: 'high',
        template_type: 'booking_reminder',
        variables: template_renderer.build_booking_variables(booking),
        channels: %w[push email sms]
      }.merge(data))
    end

    def send_booking_completed(booking, data)
      send_notification(booking.client, 'booking_completed', {
        title: 'Обслуговування завершено',
        message: 'Дякуємо за візит! Будь ласка, оцініть наш сервіс',
        category: 'booking',
        priority: 'normal',
        template_type: 'service_completed',
        variables: template_renderer.build_booking_variables(booking),
        channels: %w[push email]
      }.merge(data))
    end

    # === Operator notifications ===

    def send_operator_assigned(operator, service_point)
      variables = template_renderer.build_operator_variables(operator, service_point, 'assigned')

      delivery_manager.send_direct_email(
        to: operator.user.email,
        template: 'operator_assigned',
        variables: variables
      )

      delivery_manager.send_direct_telegram(
        user: operator.user,
        message: template_renderer.build_telegram_assignment_message(operator, service_point, 'assigned')
      )

      delivery_manager.send_direct_push(
        user: operator.user,
        title: 'Новое назначение',
        body: "Вы назначены на сервисную точку #{service_point.name}",
        data: { type: 'operator_assignment', service_point_id: service_point.id, action: 'assigned' }
      )

      delivery_manager.create_internal_notification(
        user: operator.user,
        title: 'Назначение на сервисную точку',
        message: "Вы назначены оператором на сервисную точку \"#{service_point.name}\"",
        notification_type: 'operator_assignment',
        related_id: service_point.id,
        related_type: 'ServicePoint'
      )
    end

    def send_operator_unassigned(operator, service_point)
      variables = template_renderer.build_operator_variables(operator, service_point, 'unassigned')

      delivery_manager.send_direct_email(
        to: operator.user.email,
        template: 'operator_unassigned',
        variables: variables
      )

      delivery_manager.send_direct_telegram(
        user: operator.user,
        message: template_renderer.build_telegram_assignment_message(operator, service_point, 'unassigned')
      )

      delivery_manager.send_direct_push(
        user: operator.user,
        title: 'Отзыв назначения',
        body: "Ваше назначение на сервисную точку #{service_point.name} отозвано",
        data: { type: 'operator_unassignment', service_point_id: service_point.id, action: 'unassigned' }
      )

      delivery_manager.create_internal_notification(
        user: operator.user,
        title: 'Отзыв назначения',
        message: "Ваше назначение на сервисную точку \"#{service_point.name}\" отозвано",
        notification_type: 'operator_unassignment',
        related_id: service_point.id,
        related_type: 'ServicePoint'
      )
    end

    def send_partner_new_operator(partner, operator)
      delivery_manager.send_direct_email(
        to: partner.user.email,
        template: 'partner_new_operator',
        variables: {
          partner_name: partner.user.full_name,
          operator_name: operator.user.full_name,
          operator_email: operator.user.email,
          operator_phone: operator.user.phone,
          creation_date: Time.current.strftime('%d.%m.%Y'),
          manage_operators_url: frontend_url('/admin/operators')
        }
      )

      delivery_manager.create_internal_notification(
        user: partner.user,
        title: 'Новый оператор',
        message: "Создан новый оператор: #{operator.user.full_name}",
        notification_type: 'new_operator',
        related_id: operator.id,
        related_type: 'Operator'
      )
    end

    def send_partner_operator_activated(partner, operator)
      delivery_manager.create_internal_notification(
        user: partner.user,
        title: 'Оператор активирован',
        message: "Оператор #{operator.user.full_name} активирован",
        notification_type: 'operator_activated',
        related_id: operator.id,
        related_type: 'Operator'
      )
    end

    def send_partner_operator_deactivated(partner, operator)
      delivery_manager.create_internal_notification(
        user: partner.user,
        title: 'Оператор деактивирован',
        message: "Оператор #{operator.user.full_name} деактивирован",
        notification_type: 'operator_deactivated',
        related_id: operator.id,
        related_type: 'Operator'
      )
    end

    # === Helpers ===

    def create_notification(recipient, notification_type, data, original_data)
      Notification.create(
        notification_type: notification_type,
        recipient_type: recipient.class.name,
        recipient_id: recipient.id,
        title: data[:title],
        message: data[:message],
        priority: data[:priority],
        category: data[:category],
        send_via: original_data[:channels]&.first || 'push'
      )
    rescue StandardError => e
      Rails.logger.error "Failed to create notification: #{e.message}"
      nil
    end

    def frontend_url(path)
      base_url = ENV.fetch('FRONTEND_URL', 'http://localhost:3008')
      "#{base_url}#{path}"
    end
  end
end
