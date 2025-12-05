# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notifications::DeliveryManager do
  let(:channel_router) { instance_double(Notifications::ChannelRouter) }
  let(:manager) { described_class.new(channel_router: channel_router) }

  describe '#deliver' do
    let(:notification) { instance_double(Notification, id: 1, recipient_type: 'User', recipient: user, message: 'Test') }
    let(:user) { instance_double(User, id: 1, email: 'test@example.com') }

    it 'delivers to multiple channels' do
      allow(manager).to receive(:send_email).and_return(true)
      allow(manager).to receive(:send_push).and_return(true)

      results = manager.deliver(notification, %w[email push], {})

      expect(results['email']).to be true
      expect(results['push']).to be true
    end

    it 'handles unknown channels gracefully' do
      results = manager.deliver(notification, ['unknown'], {})

      expect(results['unknown']).to be false
    end
  end

  describe '#send_email' do
    let(:user) { instance_double(User, email: 'test@example.com') }
    let(:notification) do
      instance_double(
        Notification,
        id: 1,
        recipient_type: 'User',
        recipient: user
      )
    end

    context 'with template type' do
      before do
        mailer = double('Mailer')
        allow(EmailTemplateMailer).to receive(:send_by_template).and_return(mailer)
        allow(mailer).to receive(:deliver_later)
      end

      it 'sends via EmailTemplateMailer' do
        expect(EmailTemplateMailer).to receive(:send_by_template)
          .with('booking_confirmation', 'test@example.com', { name: 'Test' })

        manager.send_email(notification, {
          template_type: 'booking_confirmation',
          variables: { name: 'Test' }
        })
      end
    end

    context 'without template type' do
      before do
        mailer = double('Mailer')
        allow(NotificationMailer).to receive(:general_notification).and_return(mailer)
        allow(mailer).to receive(:deliver_later)
      end

      it 'sends via NotificationMailer' do
        expect(NotificationMailer).to receive(:general_notification)
          .with(1, 'test@example.com')

        manager.send_email(notification, {})
      end
    end

    context 'with client recipient' do
      let(:client_user) { instance_double(User, email: 'client@example.com') }
      let(:client) { instance_double(Client, user: client_user, email: nil) }
      let(:client_notification) do
        instance_double(
          Notification,
          id: 2,
          recipient_type: 'Client',
          recipient: client
        )
      end

      before do
        mailer = double('Mailer')
        allow(NotificationMailer).to receive(:general_notification).and_return(mailer)
        allow(mailer).to receive(:deliver_later)
      end

      it 'extracts email from client user' do
        expect(NotificationMailer).to receive(:general_notification)
          .with(2, 'client@example.com')

        manager.send_email(client_notification, {})
      end
    end

    context 'without email' do
      let(:user_no_email) { instance_double(User, email: nil) }
      let(:notification_no_email) do
        instance_double(
          Notification,
          id: 3,
          recipient_type: 'User',
          recipient: user_no_email
        )
      end

      it 'returns false' do
        result = manager.send_email(notification_no_email, {})

        expect(result).to be false
      end
    end
  end

  describe '#send_push' do
    let(:notification) { instance_double(Notification, id: 1) }

    it 'logs and returns true' do
      expect(Rails.logger).to receive(:info).with(/Push notification sent/)

      result = manager.send_push(notification, {})

      expect(result).to be true
    end
  end

  describe '#send_sms' do
    let(:notification) { instance_double(Notification, id: 1) }

    it 'logs and returns true' do
      expect(Rails.logger).to receive(:info).with(/SMS notification sent/)

      result = manager.send_sms(notification, {})

      expect(result).to be true
    end
  end

  describe '#send_telegram' do
    let(:user) { instance_double(User, id: 1) }
    let(:notification) do
      instance_double(
        Notification,
        id: 1,
        recipient_type: 'User',
        recipient: user,
        message: 'Test message'
      )
    end

    before do
      allow(TelegramNotificationJob).to receive(:perform_later)
    end

    it 'queues telegram notification job' do
      expect(TelegramNotificationJob).to receive(:perform_later)
        .with(user_id: 1, message: 'Custom message')

      manager.send_telegram(notification, { message: 'Custom message' })
    end

    it 'uses notification message if no custom message' do
      expect(TelegramNotificationJob).to receive(:perform_later)
        .with(user_id: 1, message: 'Test message')

      manager.send_telegram(notification, {})
    end
  end

  describe '#send_direct_email' do
    before do
      allow(EmailNotificationJob).to receive(:perform_later)
    end

    it 'queues email notification job' do
      expect(EmailNotificationJob).to receive(:perform_later)
        .with(to: 'test@example.com', template: 'test_template', variables: { key: 'value' })

      manager.send_direct_email(
        to: 'test@example.com',
        template: 'test_template',
        variables: { key: 'value' }
      )
    end
  end

  describe '#send_direct_push' do
    before do
      allow(PushNotificationJob).to receive(:perform_later)
    end

    it 'queues push notification job' do
      user = instance_double(User, id: 1)

      expect(PushNotificationJob).to receive(:perform_later)
        .with(user_id: 1, title: 'Test', body: 'Body', data: { type: 'test' })

      manager.send_direct_push(
        user: user,
        title: 'Test',
        body: 'Body',
        data: { type: 'test' }
      )
    end
  end

  describe '#create_internal_notification' do
    let(:user) { instance_double(User) }

    before do
      allow(Notification).to receive(:create!).and_return(instance_double(Notification))
    end

    it 'creates notification in database' do
      expect(Notification).to receive(:create!).with(
        hash_including(
          user: user,
          title: 'Test Title',
          message: 'Test Message',
          notification_type: 'test_type'
        )
      )

      manager.create_internal_notification(
        user: user,
        title: 'Test Title',
        message: 'Test Message',
        notification_type: 'test_type'
      )
    end

    it 'handles errors gracefully' do
      allow(Notification).to receive(:create!).and_raise(StandardError.new('DB error'))

      result = manager.create_internal_notification(
        user: user,
        title: 'Test',
        message: 'Test',
        notification_type: 'test'
      )

      expect(result).to be_nil
    end
  end
end
