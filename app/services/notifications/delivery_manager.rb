# frozen_string_literal: true

module Notifications
  # DeliveryManager - доставка уведомлений через различные каналы
  # Отвечает за: отправку email, push, sms, telegram уведомлений
  class DeliveryManager
    attr_reader :channel_router

    def initialize(channel_router: nil)
      @channel_router = channel_router || ChannelRouter.new
    end

    # Отправляет уведомление через указанные каналы
    # @param notification [Notification] объект уведомления
    # @param channels [Array<String>] каналы для отправки
    # @param data [Hash] дополнительные данные
    # @return [Hash] результаты отправки по каналам
    def deliver(notification, channels, data)
      results = {}

      channels.each do |channel|
        results[channel] = deliver_via_channel(notification, channel, data)
      end

      results
    end

    # Отправляет email уведомление
    # @param notification [Notification] уведомление
    # @param data [Hash] данные (template_type, variables)
    # @return [Boolean] успех отправки
    def send_email(notification, data)
      recipient_email = extract_email(notification)
      return false unless recipient_email.present?

      if data[:template_type].present?
        send_template_email(data[:template_type], recipient_email, data[:variables] || {})
      else
        send_general_email(notification.id, recipient_email)
      end

      true
    rescue StandardError => e
      Rails.logger.error "Failed to send email notification: #{e.message}"
      false
    end

    # Отправляет push уведомление
    # @param notification [Notification] уведомление
    # @param data [Hash] данные (title, body, data)
    # @return [Boolean] успех отправки
    def send_push(notification, data)
      Rails.logger.info "Push notification sent for notification #{notification.id}"
      # TODO: Интеграция с Firebase FCM
      # PushNotificationJob.perform_later(...)
      true
    rescue StandardError => e
      Rails.logger.error "Failed to send push notification: #{e.message}"
      false
    end

    # Отправляет SMS уведомление
    # @param notification [Notification] уведомление
    # @param data [Hash] данные
    # @return [Boolean] успех отправки
    def send_sms(notification, data)
      Rails.logger.info "SMS notification sent for notification #{notification.id}"
      # TODO: Интеграция с SMS провайдером
      true
    rescue StandardError => e
      Rails.logger.error "Failed to send SMS notification: #{e.message}"
      false
    end

    # Отправляет Telegram уведомление
    # @param notification [Notification] уведомление
    # @param data [Hash] данные (message)
    # @return [Boolean] успех отправки
    def send_telegram(notification, data)
      user = extract_user(notification)
      return false unless user

      TelegramNotificationJob.perform_later(
        user_id: user.id,
        message: data[:message] || notification.message
      )

      Rails.logger.info "Telegram notification queued for notification #{notification.id}"
      true
    rescue StandardError => e
      Rails.logger.error "Failed to send Telegram notification: #{e.message}"
      false
    end

    # Отправляет email напрямую (без уведомления в БД)
    # @param to [String] email получателя
    # @param template [String] название шаблона
    # @param variables [Hash] переменные для шаблона
    def send_direct_email(to:, template:, variables:)
      EmailNotificationJob.perform_later(
        to: to,
        template: template,
        variables: variables
      )
    rescue StandardError => e
      Rails.logger.error "Ошибка отправки email уведомления: #{e.message}"
    end

    # Отправляет Telegram напрямую (без уведомления в БД)
    # @param user [User] пользователь
    # @param message [String] сообщение
    def send_direct_telegram(user:, message:)
      TelegramNotificationJob.perform_later(
        user_id: user.id,
        message: message
      )
    rescue StandardError => e
      Rails.logger.error "Ошибка отправки Telegram уведомления: #{e.message}"
    end

    # Отправляет push напрямую (без уведомления в БД)
    # @param user [User] пользователь
    # @param title [String] заголовок
    # @param body [String] тело сообщения
    # @param data [Hash] дополнительные данные
    def send_direct_push(user:, title:, body:, data: {})
      PushNotificationJob.perform_later(
        user_id: user.id,
        title: title,
        body: body,
        data: data
      )
    rescue StandardError => e
      Rails.logger.error "Ошибка отправки Push уведомления: #{e.message}"
    end

    # Создает внутреннее уведомление в системе
    # @param user [User] пользователь
    # @param title [String] заголовок
    # @param message [String] сообщение
    # @param notification_type [String] тип уведомления
    # @param related_id [Integer, nil] ID связанного объекта
    # @param related_type [String, nil] тип связанного объекта
    # @return [Notification, nil] созданное уведомление
    def create_internal_notification(user:, title:, message:, notification_type:, related_id: nil, related_type: nil)
      Notification.create!(
        user: user,
        title: title,
        message: message,
        notification_type: notification_type,
        related_id: related_id,
        related_type: related_type,
        is_read: false,
        created_at: Time.current
      )
    rescue StandardError => e
      Rails.logger.error "Ошибка создания внутреннего уведомления: #{e.message}"
      nil
    end

    private

    def deliver_via_channel(notification, channel, data)
      case channel.to_s
      when 'email'
        send_email(notification, data)
      when 'push'
        send_push(notification, data)
      when 'sms'
        send_sms(notification, data)
      when 'telegram'
        send_telegram(notification, data)
      else
        Rails.logger.warn "Unknown notification channel: #{channel}"
        false
      end
    end

    def extract_email(notification)
      case notification.recipient_type
      when 'User'
        notification.recipient.email
      when 'Client'
        notification.recipient.user&.email || notification.recipient.email
      else
        notification.recipient.try(:email)
      end
    end

    def extract_user(notification)
      case notification.recipient_type
      when 'User'
        notification.recipient
      when 'Client'
        notification.recipient.user
      else
        notification.recipient.try(:user)
      end
    end

    def send_template_email(template_type, email, variables)
      EmailTemplateMailer.send_by_template(
        template_type,
        email,
        variables
      ).deliver_later

      Rails.logger.info "Email отправлен через EmailTemplate: #{template_type} → #{email}"
    end

    def send_general_email(notification_id, email)
      NotificationMailer.general_notification(
        notification_id,
        email
      ).deliver_later

      Rails.logger.info "Email отправлен через NotificationMailer → #{email}"
    end
  end
end
