# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NotificationService, type: :service do
  let(:client) { create(:client) }
  let(:user) { client.user }
  let(:service_point) { create(:service_point) }
  let(:booking) { create(:booking, client: client, service_point: service_point) }

  describe 'NOTIFICATION_TYPES constant' do
    it 'includes all expected notification types' do
      expected_types = %i[
        booking_created
        booking_confirmed
        booking_cancelled
        booking_completed
        booking_reminder
        system_notification
        payment_successful
        review_request
      ]

      expected_types.each do |type|
        expect(NotificationService::NOTIFICATION_TYPES).to have_key(type)
      end
    end
  end

  describe '.send_notification' do
    let!(:notification_type) { create(:notification_type, name: 'booking_created', is_active: true) }

    context 'when notification type is active' do
      it 'creates a notification record when type exists' do
        expect {
          NotificationService.send_notification(user, 'booking_created', {
            title: 'Test notification',
            message: 'Test message'
          })
        }.to change(Notification, :count)
      end
    end

    context 'when notification type is inactive' do
      let!(:inactive_type) { create(:notification_type, name: 'inactive_type', is_active: false) }

      it 'returns false' do
        result = NotificationService.send_notification(user, 'inactive_type', {
          title: 'Test',
          message: 'Test'
        })

        expect(result).to be_falsey
      end
    end

    context 'when notification type does not exist' do
      it 'returns false' do
        result = NotificationService.send_notification(user, 'non_existent_type', {
          title: 'Test',
          message: 'Test'
        })

        expect(result).to be_falsey
      end
    end
  end

  describe '.booking_notification' do
    let!(:booking_created_type) { create(:notification_type, name: 'booking_created', is_active: true) }
    let!(:booking_confirmed_type) { create(:notification_type, name: 'booking_confirmed', is_active: true) }
    let!(:booking_cancelled_type) { create(:notification_type, name: 'booking_cancelled', is_active: true) }
    let!(:booking_reminder_type) { create(:notification_type, name: 'booking_reminder', is_active: true) }
    let!(:booking_completed_type) { create(:notification_type, name: 'booking_completed', is_active: true) }

    context 'with :created type' do
      it 'does not raise an error' do
        expect {
          NotificationService.booking_notification(booking, :created)
        }.not_to raise_error
      end
    end

    context 'with :confirmed type' do
      it 'does not raise an error' do
        expect {
          NotificationService.booking_notification(booking, :confirmed)
        }.not_to raise_error
      end
    end

    context 'with :cancelled type' do
      it 'does not raise an error' do
        expect {
          NotificationService.booking_notification(booking, :cancelled)
        }.not_to raise_error
      end
    end

    context 'with :reminder type' do
      it 'does not raise an error' do
        expect {
          NotificationService.booking_notification(booking, :reminder)
        }.not_to raise_error
      end
    end

    context 'with :completed type' do
      it 'does not raise an error' do
        expect {
          NotificationService.booking_notification(booking, :completed)
        }.not_to raise_error
      end
    end
  end

  describe '.build_booking_variables' do
    it 'returns a hash' do
      variables = NotificationService.build_booking_variables(booking)
      expect(variables).to be_a(Hash)
    end

    it 'includes company name' do
      variables = NotificationService.build_booking_variables(booking)
      expect(variables).to have_key('company_name')
      expect(variables['company_name']).to eq('Tire Service Master')
    end

    it 'includes booking_id' do
      variables = NotificationService.build_booking_variables(booking)
      expect(variables).to have_key('booking_id')
      expect(variables['booking_id']).to eq("##{booking.id}")
    end

    it 'includes client information keys' do
      variables = NotificationService.build_booking_variables(booking)
      expect(variables).to have_key('client_name')
      expect(variables).to have_key('client_phone')
      expect(variables).to have_key('client_email')
    end

    it 'includes booking date and time' do
      variables = NotificationService.build_booking_variables(booking)
      expect(variables).to have_key('booking_date')
      expect(variables).to have_key('booking_time')
      expect(variables).to have_key('booking_status')
    end

    it 'includes service point information' do
      variables = NotificationService.build_booking_variables(booking)
      expect(variables).to have_key('service_point_name')
      expect(variables).to have_key('service_point_address')
    end
  end

  describe 'instance methods' do
    let(:service) { NotificationService.new }

    describe '#send_operator_assignment_notification' do
      let(:operator) { create(:operator) }

      context 'when action_type is assigned' do
        it 'does not raise an error' do
          expect {
            service.send_operator_assignment_notification(operator, service_point, 'assigned')
          }.not_to raise_error
        end
      end

      context 'when action_type is unassigned' do
        it 'does not raise an error' do
          expect {
            service.send_operator_assignment_notification(operator, service_point, 'unassigned')
          }.not_to raise_error
        end
      end

      context 'when operator is nil' do
        it 'returns nil' do
          result = service.send_operator_assignment_notification(nil, service_point, 'assigned')
          expect(result).to be_nil
        end
      end

      context 'when service_point is nil' do
        it 'returns nil' do
          result = service.send_operator_assignment_notification(operator, nil, 'assigned')
          expect(result).to be_nil
        end
      end
    end

    describe '#send_partner_operator_notification' do
      let(:partner) { create(:partner) }
      let(:operator) { create(:operator) }

      context 'when action_type is operator_created' do
        it 'does not raise an error' do
          expect {
            service.send_partner_operator_notification(partner, operator, 'operator_created')
          }.not_to raise_error
        end
      end

      context 'when action_type is operator_activated' do
        it 'does not raise an error' do
          expect {
            service.send_partner_operator_notification(partner, operator, 'operator_activated')
          }.not_to raise_error
        end
      end

      context 'when action_type is operator_deactivated' do
        it 'does not raise an error' do
          expect {
            service.send_partner_operator_notification(partner, operator, 'operator_deactivated')
          }.not_to raise_error
        end
      end

      context 'when partner is nil' do
        it 'returns nil' do
          result = service.send_partner_operator_notification(nil, operator, 'operator_created')
          expect(result).to be_nil
        end
      end
    end
  end

  describe '.send_operator_assignment_notification (class method)' do
    let(:operator) { create(:operator) }

    it 'delegates to instance method' do
      expect_any_instance_of(NotificationService).to receive(:send_operator_assignment_notification)
        .with(operator, service_point, 'assigned')

      NotificationService.send_operator_assignment_notification(operator, service_point, 'assigned')
    end
  end

  describe '.send_partner_operator_notification (class method)' do
    let(:partner) { create(:partner) }
    let(:operator) { create(:operator) }

    it 'delegates to instance method' do
      expect_any_instance_of(NotificationService).to receive(:send_partner_operator_notification)
        .with(partner, operator, 'operator_created')

      NotificationService.send_partner_operator_notification(partner, operator, 'operator_created')
    end
  end
end
