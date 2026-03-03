# frozen_string_literal: true

# Job for sending notifications about order status changes to customers
# Supports SMS and Push notifications
class OrderNotificationJob < ApplicationJob
  queue_as :notifications

  # Retry on temporary failures
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  # Handle permanently failed jobs
  sidekiq_retries_exhausted do |msg, _ex|
    Rails.logger.error "[OrderNotificationJob] Permanently failed: #{msg['error_message']}"
    SystemLog.create(
      action: 'job_permanently_failed',
      resource_type: 'OrderNotificationJob',
      resource_id: msg['args']&.first,
      additional_data: { error: msg['error_message'], job_id: msg['jid'], args: msg['args'] }
    ) rescue nil
    AdminNotificationService.notify_job_permanently_failed(
      job_class: 'OrderNotificationJob',
      error_message: msg['error_message'],
      job_id: msg['jid']
    ) if defined?(AdminNotificationService)
  end

  # @param order_id [Integer] Order ID
  # @param notification_type [String] Type: order_ready, order_delivered, order_canceled
  def perform(order_id, notification_type)
    @order = Order.find_by(id: order_id)
    return unless @order

    Rails.logger.info "📦 OrderNotificationJob: Sending #{notification_type} notification for order ##{@order.ttn}"

    case notification_type
    when 'order_ready'
      send_order_ready_notification
    when 'order_delivered'
      send_order_delivered_notification
    when 'order_canceled'
      send_order_canceled_notification
    else
      Rails.logger.warn "Unknown notification type: #{notification_type}"
    end
  end

  private

  def send_order_ready_notification
    # Send SMS
    send_sms(
      I18n.t('notifications.order.ready.title', default: 'Замовлення готове!'),
      I18n.t('notifications.order.ready.message',
             ttn: @order.ttn,
             point_name: @order.point_name,
             default: "Ваше замовлення ##{@order.ttn} готове до видачі в #{@order.point_name}")
    )

    # Create internal notification for tracking
    create_internal_notification('order_ready', 'Замовлення готове до видачі')
  end

  def send_order_delivered_notification
    # Send SMS
    send_sms(
      I18n.t('notifications.order.delivered.title', default: 'Замовлення видано'),
      I18n.t('notifications.order.delivered.message',
             ttn: @order.ttn,
             default: "Ваше замовлення ##{@order.ttn} успішно видано. Дякуємо за покупку!")
    )

    # Create internal notification
    create_internal_notification('order_delivered', 'Замовлення успішно видано')
  end

  def send_order_canceled_notification
    # Send SMS
    send_sms(
      I18n.t('notifications.order.canceled.title', default: 'Замовлення скасовано'),
      I18n.t('notifications.order.canceled.message',
             ttn: @order.ttn,
             default: "На жаль, ваше замовлення ##{@order.ttn} було скасовано. Зверніться до служби підтримки.")
    )

    # Create internal notification
    create_internal_notification('order_canceled', 'Замовлення скасовано')
  end

  def send_sms(title, message)
    return unless @order.customer_phone.present?

    begin
      SmsService.send_message(
        phone: @order.customer_phone,
        message: message
      )
      Rails.logger.info "✅ SMS sent to #{mask_phone(@order.customer_phone)} for order ##{@order.ttn}"
    rescue => e
      Rails.logger.error "❌ Failed to send SMS for order ##{@order.ttn}: #{e.message}"
    end
  end

  def create_internal_notification(type, message)
    # Find or create notification type
    notification_type = NotificationType.find_or_create_by!(
      name: type,
      defaults: { description: message, category: 'order' }
    )

    # Create notification record for tracking
    Notification.create!(
      notification_type: notification_type,
      recipient_type: 'Order',
      recipient_id: @order.id,
      title: message,
      message: "Замовлення ##{@order.ttn}",
      priority: 'normal',
      category: 'order',
      send_via: 'sms',
      sent_at: Time.current
    )
  rescue => e
    Rails.logger.warn "Failed to create internal notification: #{e.message}"
  end

  def mask_phone(phone)
    return phone if phone.length < 6
    "#{phone[0..4]}***#{phone[-2..]}"
  end
end
