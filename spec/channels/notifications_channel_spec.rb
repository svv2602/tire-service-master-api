# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NotificationsChannel, type: :channel do
  let(:user) { create(:user) }
  let(:notification_type) { create(:notification_type, name: 'system_notification', is_active: true) }
  let(:notification) do
    create(:notification,
           notification_type: notification_type,
           recipient_type: 'User',
           recipient_id: user.id,
           skip_broadcasts: true)
  end

  before do
    stub_connection(current_user: user)
  end

  describe '#subscribed' do
    it 'subscribes to user notifications stream' do
      subscribe

      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from("notifications:user_#{user.id}")
    end

    it 'transmits initial unread count' do
      # Create some unread notifications
      create_list(:notification, 3,
                  notification_type: notification_type,
                  recipient_type: 'User',
                  recipient_id: user.id,
                  is_read: false,
                  skip_broadcasts: true)

      subscribe

      expect(transmissions).to include(hash_including('type' => 'unread_count', 'count' => 3))
    end
  end

  describe '#unsubscribed' do
    it 'unsubscribes without errors' do
      subscribe
      expect { subscription.unsubscribe_from_channel }.not_to raise_error
    end
  end

  describe '#mark_as_read' do
    before do
      subscribe
    end

    it 'marks notification as read' do
      perform :mark_as_read, notification_id: notification.id

      expect(notification.reload.is_read).to be true
      expect(notification.read_at).to be_present
    end

    it 'does not mark notification for other user' do
      other_user = create(:user)
      other_notification = create(:notification,
                                  notification_type: notification_type,
                                  recipient_type: 'User',
                                  recipient_id: other_user.id,
                                  skip_broadcasts: true)

      perform :mark_as_read, notification_id: other_notification.id

      expect(other_notification.reload.is_read).to be false
    end
  end

  describe '#mark_all_as_read' do
    before do
      subscribe
      create_list(:notification, 3,
                  notification_type: notification_type,
                  recipient_type: 'User',
                  recipient_id: user.id,
                  is_read: false,
                  skip_broadcasts: true)
    end

    it 'marks all notifications as read' do
      perform :mark_all_as_read

      expect(Notification.for_recipient('User', user.id).unread.count).to eq(0)
    end
  end

  describe '.broadcast_notification' do
    it 'broadcasts to user channel' do
      expect do
        NotificationsChannel.broadcast_notification(user, notification)
      end.to have_broadcasted_to("notifications:user_#{user.id}")
        .with(hash_including(type: 'new_notification'))
    end

    it 'includes notification details' do
      expect do
        NotificationsChannel.broadcast_notification(user, notification)
      end.to have_broadcasted_to("notifications:user_#{user.id}")
        .with(hash_including(
                notification: hash_including(
                  id: notification.id,
                  title: notification.title,
                  message: notification.message,
                  priority: notification.priority,
                  category: notification.category
                )
              ))
    end

    it 'includes unread count' do
      create(:notification,
             notification_type: notification_type,
             recipient_type: 'User',
             recipient_id: user.id,
             is_read: false,
             skip_broadcasts: true)

      expect do
        NotificationsChannel.broadcast_notification(user, notification)
      end.to have_broadcasted_to("notifications:user_#{user.id}")
        .with(hash_including(unread_count: 2))
    end
  end

  describe '.broadcast_unread_count' do
    it 'broadcasts unread count to user channel' do
      create_list(:notification, 2,
                  notification_type: notification_type,
                  recipient_type: 'User',
                  recipient_id: user.id,
                  is_read: false,
                  skip_broadcasts: true)

      expect do
        NotificationsChannel.broadcast_unread_count(user)
      end.to have_broadcasted_to("notifications:user_#{user.id}")
        .with(hash_including(type: 'unread_count', count: 2))
    end
  end

  describe '.broadcast_system_alert' do
    context 'to all users' do
      it 'broadcasts to system channel' do
        expect do
          NotificationsChannel.broadcast_system_alert('System maintenance', priority: 'high')
        end.to have_broadcasted_to('notifications:system')
          .with(hash_including(
                  type: 'system_alert',
                  priority: 'high',
                  message: 'System maintenance'
                ))
      end
    end

    context 'to specific users' do
      let(:other_user) { create(:user) }

      it 'broadcasts to specific user channels' do
        expect do
          NotificationsChannel.broadcast_system_alert('Alert', users: [user, other_user])
        end.to have_broadcasted_to("notifications:user_#{user.id}")
          .and have_broadcasted_to("notifications:user_#{other_user.id}")
      end
    end
  end

  describe '.broadcast_notification_read' do
    it 'broadcasts notification read event' do
      expect do
        NotificationsChannel.broadcast_notification_read(user, notification.id)
      end.to have_broadcasted_to("notifications:user_#{user.id}")
        .with(hash_including(
                type: 'notification_read',
                notification_id: notification.id
              ))
    end
  end

  describe 'Notification model integration' do
    context 'when notification is created' do
      it 'can call broadcast_new_notification method' do
        new_notification = build(:notification,
                                 notification_type: notification_type,
                                 recipient_type: 'User',
                                 recipient_id: user.id,
                                 skip_broadcasts: true)

        expect(new_notification.private_methods).to include(:broadcast_new_notification)
      end
    end

    context 'when notification is marked as read' do
      before do
        notification.skip_broadcasts = false
      end

      it 'broadcasts read status event' do
        allow(NotificationsChannel).to receive(:broadcast_notification_read)

        notification.mark_as_read!

        expect(NotificationsChannel).to have_received(:broadcast_notification_read).with(user, notification.id)
      end
    end
  end
end
