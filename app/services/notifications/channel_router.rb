# frozen_string_literal: true

module Notifications
  # ChannelRouter - определение каналов доставки уведомлений
  # Отвечает за: выбор каналов (email, push, sms, telegram), приоритеты
  class ChannelRouter
    AVAILABLE_CHANNELS = %w[email push sms telegram].freeze

    DEFAULT_CHANNELS = {
      'booking_created' => %w[push email],
      'booking_confirmed' => %w[push email sms],
      'booking_cancelled' => %w[push email sms],
      'booking_completed' => %w[push email],
      'booking_reminder' => %w[push email sms],
      'system_notification' => %w[push email],
      'payment_successful' => %w[push email],
      'review_request' => %w[push email],
      'operator_assignment' => %w[email telegram push],
      'operator_unassignment' => %w[email telegram push],
      'new_operator' => %w[email],
      'operator_activated' => %w[push],
      'operator_deactivated' => %w[push]
    }.freeze

    # Определяет каналы для отправки уведомления
    # @param notification_type [NotificationType] тип уведомления
    # @param requested_channels [Array<String>, nil] явно запрошенные каналы
    # @return [Array<String>] список каналов для отправки
    def determine_channels(notification_type, requested_channels = nil)
      return filter_available(requested_channels) if requested_channels.present?

      channels_from_type(notification_type)
    end

    # Получает каналы из типа уведомления
    # @param notification_type [NotificationType] тип уведомления
    # @return [Array<String>] список каналов
    def channels_from_type(notification_type)
      channels = []

      if notification_type.respond_to?(:is_push?) && notification_type.is_push?
        channels << 'push'
      end

      if notification_type.respond_to?(:is_email?) && notification_type.is_email?
        channels << 'email'
      end

      if notification_type.respond_to?(:is_sms?) && notification_type.is_sms?
        channels << 'sms'
      end

      if notification_type.respond_to?(:is_telegram?) && notification_type.is_telegram?
        channels << 'telegram'
      end

      channels.presence || default_channels_for(notification_type.name)
    end

    # Возвращает каналы по умолчанию для типа
    # @param type_name [String] название типа уведомления
    # @return [Array<String>] каналы по умолчанию
    def default_channels_for(type_name)
      DEFAULT_CHANNELS[type_name] || %w[push]
    end

    # Проверяет, доступен ли канал
    # @param channel [String] название канала
    # @return [Boolean]
    def channel_available?(channel)
      AVAILABLE_CHANNELS.include?(channel.to_s)
    end

    # Проверяет, может ли получатель принять уведомление через канал
    # @param recipient [User, Client] получатель
    # @param channel [String] канал
    # @return [Boolean]
    def recipient_supports_channel?(recipient, channel)
      case channel.to_s
      when 'email'
        email_for_recipient(recipient).present?
      when 'push'
        # Push-уведомления доступны для всех зарегистрированных пользователей
        true
      when 'sms'
        phone_for_recipient(recipient).present?
      when 'telegram'
        telegram_available_for?(recipient)
      else
        false
      end
    end

    # Фильтрует каналы, оставляя только те, которые поддерживает получатель
    # @param recipient [User, Client] получатель
    # @param channels [Array<String>] запрошенные каналы
    # @return [Array<String>] поддерживаемые каналы
    def filter_channels_for_recipient(recipient, channels)
      channels.select { |channel| recipient_supports_channel?(recipient, channel) }
    end

    private

    def filter_available(channels)
      Array(channels).select { |c| channel_available?(c) }
    end

    def email_for_recipient(recipient)
      case recipient
      when User
        recipient.email
      when Client
        recipient.user&.email || recipient.email
      else
        recipient.try(:email)
      end
    end

    def phone_for_recipient(recipient)
      case recipient
      when User
        recipient.phone
      when Client
        recipient.user&.phone || recipient.phone
      else
        recipient.try(:phone)
      end
    end

    def telegram_available_for?(recipient)
      user = recipient.is_a?(User) ? recipient : recipient.try(:user)
      return false unless user

      user.telegram_subscription&.can_receive_notifications?
    end
  end
end
