# frozen_string_literal: true

# Real-time notifications for all authenticated users
# Provides live updates for notifications, unread counts, and system alerts
class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    # Subscribe to user's personal notification stream
    stream_from "notifications:user_#{current_user.id}"
    log_subscription("notifications:user_#{current_user.id}")

    # Send initial unread count on connection
    transmit_unread_count
  end

  def unsubscribed
    log_unsubscription("notifications:user_#{current_user.id}")
  end

  # Mark notification as read (called from frontend)
  def mark_as_read(data)
    notification_id = data['notification_id']
    notification = find_user_notification(notification_id)

    if notification&.mark_as_read!
      # Broadcast updated unread count
      self.class.broadcast_unread_count(current_user)
    end
  end

  # Mark all notifications as read
  def mark_all_as_read
    user_notifications.unread.update_all(is_read: true, read_at: Time.current)
    self.class.broadcast_unread_count(current_user)
  end

  private

  def transmit_unread_count
    transmit({
               type: 'unread_count',
               count: user_notifications.unread.count
             })
  end

  def user_notifications
    Notification.for_recipient('User', current_user.id)
  end

  def find_user_notification(notification_id)
    user_notifications.find_by(id: notification_id)
  end

  # Class methods for broadcasting from services
  class << self
    # Broadcast new notification to user
    def broadcast_notification(user, notification)
      ActionCable.server.broadcast(
        "notifications:user_#{user.id}",
        {
          type: 'new_notification',
          notification: serialize_notification(notification),
          unread_count: Notification.for_recipient('User', user.id).unread.count
        }
      )
    end

    # Broadcast updated unread count to user
    def broadcast_unread_count(user)
      ActionCable.server.broadcast(
        "notifications:user_#{user.id}",
        {
          type: 'unread_count',
          count: Notification.for_recipient('User', user.id).unread.count
        }
      )
    end

    # Broadcast system alert to all users or specific users
    def broadcast_system_alert(message, users: nil, priority: 'normal')
      data = {
        type: 'system_alert',
        priority: priority,
        message: message,
        timestamp: Time.current.iso8601
      }

      if users.nil?
        # Broadcast to all connected users
        ActionCable.server.broadcast('notifications:system', data)
      else
        # Broadcast to specific users
        Array(users).each do |user|
          ActionCable.server.broadcast("notifications:user_#{user.id}", data)
        end
      end
    end

    # Broadcast notification marked as read
    def broadcast_notification_read(user, notification_id)
      ActionCable.server.broadcast(
        "notifications:user_#{user.id}",
        {
          type: 'notification_read',
          notification_id: notification_id,
          unread_count: Notification.for_recipient('User', user.id).unread.count
        }
      )
    end

    private

    def serialize_notification(notification)
      {
        id: notification.id,
        title: notification.title,
        message: notification.message,
        priority: notification.priority,
        category: notification.category,
        is_read: notification.is_read,
        send_via: notification.send_via,
        created_at: notification.created_at,
        read_at: notification.read_at
      }
    end
  end
end
