# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notifications::Service do
  let(:channel_router) { instance_double(Notifications::ChannelRouter) }
  let(:template_renderer) { instance_double(Notifications::TemplateRenderer) }
  let(:delivery_manager) { instance_double(Notifications::DeliveryManager) }
  let(:service) do
    described_class.new(
      channel_router: channel_router,
      template_renderer: template_renderer,
      delivery_manager: delivery_manager
    )
  end

  describe '#initialize' do
    it 'creates with default dependencies' do
      service = described_class.new

      expect(service.channel_router).to be_a(Notifications::ChannelRouter)
      expect(service.template_renderer).to be_a(Notifications::TemplateRenderer)
      expect(service.delivery_manager).to be_a(Notifications::DeliveryManager)
    end

    it 'accepts custom dependencies' do
      expect(service.channel_router).to eq(channel_router)
      expect(service.template_renderer).to eq(template_renderer)
      expect(service.delivery_manager).to eq(delivery_manager)
    end
  end

  describe '#send_notification' do
    let(:recipient) { instance_double(User, id: 1, class: User) }
    let(:notification_type) { instance_double(NotificationType, name: 'test', is_active?: true, template: nil) }
    let(:notification) { instance_double(Notification) }

    before do
      allow(NotificationType).to receive(:find_by).with(name: 'test').and_return(notification_type)
      allow(template_renderer).to receive(:prepare_notification_data).and_return({
        title: 'Test',
        message: 'Test message',
        priority: 'normal',
        category: 'general'
      })
      allow(Notification).to receive(:create).and_return(notification)
      allow(channel_router).to receive(:determine_channels).and_return(%w[email push])
      allow(delivery_manager).to receive(:deliver).and_return({ 'email' => true, 'push' => true })
      allow(notification).to receive(:mark_as_sent!)
    end

    it 'creates notification and delivers through channels' do
      expect(Notification).to receive(:create)
      expect(delivery_manager).to receive(:deliver).with(notification, %w[email push], anything)
      expect(notification).to receive(:mark_as_sent!)

      result = service.send_notification(recipient, 'test', {})

      expect(result).to eq(notification)
    end

    it 'returns false if notification type not found' do
      allow(NotificationType).to receive(:find_by).and_return(nil)

      result = service.send_notification(recipient, 'unknown', {})

      expect(result).to be false
    end

    it 'returns false if notification type is inactive' do
      allow(notification_type).to receive(:is_active?).and_return(false)

      result = service.send_notification(recipient, 'test', {})

      expect(result).to be false
    end
  end

  describe '#booking_notification' do
    let(:client) { instance_double(Client) }
    let(:booking) do
      instance_double(
        Booking,
        client: client,
        booking_date: Date.new(2024, 1, 15),
        start_time: Time.zone.parse('2024-01-15 10:00')
      )
    end

    before do
      allow(service).to receive(:send_notification).and_return(true)
      allow(template_renderer).to receive(:build_booking_variables).and_return({})
    end

    it 'sends created notification' do
      expect(service).to receive(:send_notification).with(
        client,
        'booking_created',
        hash_including(title: 'Бронювання створено', channels: %w[push email])
      )

      service.booking_notification(booking, :created)
    end

    it 'sends confirmed notification' do
      expect(service).to receive(:send_notification).with(
        client,
        'booking_confirmed',
        hash_including(title: 'Бронювання підтверджено', priority: 'high')
      )

      service.booking_notification(booking, :confirmed)
    end

    it 'sends cancelled notification' do
      expect(service).to receive(:send_notification).with(
        client,
        'booking_cancelled',
        hash_including(title: 'Бронювання скасовано')
      )

      service.booking_notification(booking, :cancelled)
    end

    it 'sends reminder notification' do
      expect(service).to receive(:send_notification).with(
        client,
        'booking_reminder',
        hash_including(title: 'Нагадування про запис')
      )

      service.booking_notification(booking, :reminder)
    end

    it 'sends completed notification' do
      expect(service).to receive(:send_notification).with(
        client,
        'booking_completed',
        hash_including(title: 'Обслуговування завершено')
      )

      service.booking_notification(booking, :completed)
    end
  end

  describe '#system_notification' do
    let(:user1) { instance_double(User) }
    let(:user2) { instance_double(User) }

    before do
      allow(service).to receive(:send_notification).and_return(true)
    end

    it 'sends to single recipient' do
      expect(service).to receive(:send_notification).with(
        user1,
        'system_notification',
        hash_including(title: 'System Alert', message: 'Important message')
      )

      service.system_notification(user1, 'System Alert', 'Important message')
    end

    it 'sends to multiple recipients' do
      expect(service).to receive(:send_notification).twice

      service.system_notification([user1, user2], 'Alert', 'Message')
    end
  end

  describe '#send_operator_assignment_notification' do
    let(:user) { instance_double(User, email: 'op@example.com', first_name: 'Op') }
    let(:operator) { instance_double(Operator, user: user) }
    let(:partner) { instance_double(Partner, name: 'Partner') }
    let(:service_point) do
      instance_double(
        ServicePoint,
        id: 1,
        name: 'СТО',
        address: 'Address',
        phone: '+380441234567',
        partner: partner
      )
    end

    before do
      allow(template_renderer).to receive(:build_operator_variables).and_return({})
      allow(template_renderer).to receive(:build_telegram_assignment_message).and_return('Message')
      allow(delivery_manager).to receive(:send_direct_email)
      allow(delivery_manager).to receive(:send_direct_telegram)
      allow(delivery_manager).to receive(:send_direct_push)
      allow(delivery_manager).to receive(:create_internal_notification)
    end

    it 'sends assigned notifications through all channels' do
      expect(delivery_manager).to receive(:send_direct_email)
      expect(delivery_manager).to receive(:send_direct_telegram)
      expect(delivery_manager).to receive(:send_direct_push)
      expect(delivery_manager).to receive(:create_internal_notification)

      service.send_operator_assignment_notification(operator, service_point, 'assigned')
    end

    it 'sends unassigned notifications' do
      expect(delivery_manager).to receive(:send_direct_email)
      expect(delivery_manager).to receive(:create_internal_notification)

      service.send_operator_assignment_notification(operator, service_point, 'unassigned')
    end

    it 'returns nil if operator or service_point is nil' do
      result = service.send_operator_assignment_notification(nil, service_point, 'assigned')
      expect(result).to be_nil

      result = service.send_operator_assignment_notification(operator, nil, 'assigned')
      expect(result).to be_nil
    end
  end

  describe '#send_partner_operator_notification' do
    let(:partner_user) { instance_double(User, email: 'partner@example.com', full_name: 'Partner') }
    let(:partner) { instance_double(Partner, user: partner_user) }
    let(:operator_user) { instance_double(User, full_name: 'Operator', email: 'op@example.com', phone: '+380501234567') }
    let(:operator) { instance_double(Operator, id: 1, user: operator_user) }

    before do
      allow(delivery_manager).to receive(:send_direct_email)
      allow(delivery_manager).to receive(:create_internal_notification)
    end

    it 'sends new operator notification' do
      expect(delivery_manager).to receive(:send_direct_email)
      expect(delivery_manager).to receive(:create_internal_notification)

      service.send_partner_operator_notification(partner, operator, 'operator_created')
    end

    it 'sends activated notification' do
      expect(delivery_manager).to receive(:create_internal_notification)

      service.send_partner_operator_notification(partner, operator, 'operator_activated')
    end

    it 'sends deactivated notification' do
      expect(delivery_manager).to receive(:create_internal_notification)

      service.send_partner_operator_notification(partner, operator, 'operator_deactivated')
    end
  end

  describe 'NOTIFICATION_TYPES constant' do
    it 'includes all booking notification types' do
      expect(described_class::NOTIFICATION_TYPES).to include(
        booking_created: 'booking_created',
        booking_confirmed: 'booking_confirmed',
        booking_cancelled: 'booking_cancelled',
        booking_completed: 'booking_completed',
        booking_reminder: 'booking_reminder'
      )
    end

    it 'includes system notification types' do
      expect(described_class::NOTIFICATION_TYPES).to include(
        system_notification: 'system_notification',
        payment_successful: 'payment_successful',
        review_request: 'review_request'
      )
    end
  end
end
