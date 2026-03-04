# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BookingEventPublisher do
  let(:service_point) { instance_double(ServicePoint, partner: partner, active_operators: []) }
  let(:partner) { instance_double(Partner, user: partner_user) }
  let(:partner_user) { instance_double(User, email: 'partner@test.com', id: 10) }

  # Build a booking double that behaves like a real saved record
  def build_booking(saved_changes: {}, previously_new_record: false, id: 1)
    booking = instance_double(
      Booking,
      id: id,
      saved_changes: saved_changes,
      previously_new_record?: previously_new_record,
      service_point: service_point,
      status: saved_changes.dig('status', 1) || 'pending'
    )
    booking
  end

  describe '#detect_event' do
    context 'when booking is newly created' do
      it 'returns :booking_created' do
        booking = build_booking(previously_new_record: true)
        publisher = described_class.new(booking)

        expect(publisher.detect_event).to eq(:booking_created)
      end
    end

    context 'when status changes to confirmed' do
      it 'returns :booking_confirmed' do
        booking = build_booking(saved_changes: { 'status' => ['pending', 'confirmed'] })
        publisher = described_class.new(booking)

        expect(publisher.detect_event).to eq(:booking_confirmed)
      end
    end

    context 'when status changes to cancelled_by_client' do
      it 'returns :booking_cancelled' do
        booking = build_booking(saved_changes: { 'status' => ['confirmed', 'cancelled_by_client'] })
        publisher = described_class.new(booking)

        expect(publisher.detect_event).to eq(:booking_cancelled)
      end
    end

    context 'when status changes to cancelled_by_partner' do
      it 'returns :booking_cancelled' do
        booking = build_booking(saved_changes: { 'status' => ['confirmed', 'cancelled_by_partner'] })
        publisher = described_class.new(booking)

        expect(publisher.detect_event).to eq(:booking_cancelled)
      end
    end

    context 'when status changes to completed' do
      it 'returns :booking_completed' do
        booking = build_booking(saved_changes: { 'status' => ['in_progress', 'completed'] })
        publisher = described_class.new(booking)

        expect(publisher.detect_event).to eq(:booking_completed)
      end
    end

    context 'when status changes to in_progress' do
      it 'returns :booking_in_progress' do
        booking = build_booking(saved_changes: { 'status' => ['confirmed', 'in_progress'] })
        publisher = described_class.new(booking)

        expect(publisher.detect_event).to eq(:booking_in_progress)
      end
    end

    context 'when status changes to no_show' do
      it 'returns :booking_no_show' do
        booking = build_booking(saved_changes: { 'status' => ['confirmed', 'no_show'] })
        publisher = described_class.new(booking)

        expect(publisher.detect_event).to eq(:booking_no_show)
      end
    end

    context 'when start_time changed' do
      it 'returns :booking_time_changed' do
        booking = build_booking(saved_changes: { 'start_time' => ['10:00', '11:00'] })
        publisher = described_class.new(booking)

        expect(publisher.detect_event).to eq(:booking_time_changed)
      end
    end

    context 'when booking_date changed' do
      it 'returns :booking_time_changed' do
        booking = build_booking(saved_changes: { 'booking_date' => ['2026-03-01', '2026-03-02'] })
        publisher = described_class.new(booking)

        expect(publisher.detect_event).to eq(:booking_time_changed)
      end
    end

    context 'when service_point_id changed' do
      it 'returns :booking_location_changed' do
        booking = build_booking(saved_changes: { 'service_point_id' => [1, 2] })
        publisher = described_class.new(booking)

        expect(publisher.detect_event).to eq(:booking_location_changed)
      end
    end

    context 'when client info changed' do
      it 'returns :booking_client_info_changed for first name change' do
        booking = build_booking(saved_changes: { 'service_recipient_first_name' => ['John', 'Jane'] })
        publisher = described_class.new(booking)

        expect(publisher.detect_event).to eq(:booking_client_info_changed)
      end

      it 'returns :booking_client_info_changed for phone change' do
        booking = build_booking(saved_changes: { 'service_recipient_phone' => ['+380111', '+380222'] })
        publisher = described_class.new(booking)

        expect(publisher.detect_event).to eq(:booking_client_info_changed)
      end
    end

    context 'when no relevant changes' do
      it 'returns nil for non-notification fields' do
        booking = build_booking(saved_changes: { 'total_price' => [100, 200] })
        publisher = described_class.new(booking)

        expect(publisher.detect_event).to be_nil
      end

      it 'returns nil for empty saved_changes on non-new record' do
        booking = build_booking(saved_changes: {})
        publisher = described_class.new(booking)

        expect(publisher.detect_event).to be_nil
      end
    end

    context 'priority: when multiple changes happen in one save' do
      it 'prioritizes status change (cancelled) over time change' do
        booking = build_booking(
          saved_changes: {
            'status' => ['confirmed', 'cancelled_by_client'],
            'start_time' => ['10:00', '11:00']
          }
        )
        publisher = described_class.new(booking)

        expect(publisher.detect_event).to eq(:booking_cancelled)
      end

      it 'prioritizes status change (confirmed) over location change' do
        booking = build_booking(
          saved_changes: {
            'status' => ['pending', 'confirmed'],
            'service_point_id' => [1, 2]
          }
        )
        publisher = described_class.new(booking)

        expect(publisher.detect_event).to eq(:booking_confirmed)
      end

      it 'prioritizes time change over location change' do
        booking = build_booking(
          saved_changes: {
            'start_time' => ['10:00', '11:00'],
            'service_point_id' => [1, 2]
          }
        )
        publisher = described_class.new(booking)

        expect(publisher.detect_event).to eq(:booking_time_changed)
      end

      it 'prioritizes location change over client info change' do
        booking = build_booking(
          saved_changes: {
            'service_point_id' => [1, 2],
            'service_recipient_first_name' => ['John', 'Jane']
          }
        )
        publisher = described_class.new(booking)

        expect(publisher.detect_event).to eq(:booking_location_changed)
      end
    end
  end

  describe '#call' do
    before do
      allow(BookingNotificationJob).to receive(:perform_later)
      # Stub ENV for admin emails
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('ADMIN_NOTIFICATION_EMAILS').and_return('admin@test.com')
    end

    context 'when booking is created' do
      it 'dispatches exactly the expected notifications' do
        booking = build_booking(previously_new_record: true)
        allow(service_point).to receive(:active_operators).and_return([])

        result = described_class.call(booking)

        expect(result).to eq(:booking_created)
        # Client email, admin email, client telegram, partner email, partner push, partner telegram
        expect(BookingNotificationJob).to have_received(:perform_later).with(1, 'booking_created')
        expect(BookingNotificationJob).to have_received(:perform_later).with(1, 'admin_new_booking', 'admin@test.com')
        expect(BookingNotificationJob).to have_received(:perform_later).with(1, 'telegram_booking_created')
        expect(BookingNotificationJob).to have_received(:perform_later).with(1, 'partner_new_booking', 'partner@test.com')
        expect(BookingNotificationJob).to have_received(:perform_later).with(1, 'push_partner_new_booking')
        expect(BookingNotificationJob).to have_received(:perform_later).with(1, 'telegram_partner_new_booking')
      end

      it 'dispatches operator notifications when operators exist' do
        operator_user = instance_double(User, id: 20)
        operator = instance_double(Operator, user: operator_user)
        allow(service_point).to receive(:active_operators).and_return([operator])

        booking = build_booking(previously_new_record: true)

        described_class.call(booking)

        expect(BookingNotificationJob).to have_received(:perform_later).with(1, 'push_operator_new_booking', '20')
      end
    end

    context 'when booking is cancelled' do
      it 'dispatches cancellation notifications' do
        booking = build_booking(saved_changes: { 'status' => ['confirmed', 'cancelled_by_client'] })
        allow(service_point).to receive(:active_operators).and_return([])

        result = described_class.call(booking)

        expect(result).to eq(:booking_cancelled)
        expect(BookingNotificationJob).to have_received(:perform_later).with(1, 'booking_cancelled')
        expect(BookingNotificationJob).to have_received(:perform_later).with(1, 'admin_booking_cancelled', 'admin@test.com')
        expect(BookingNotificationJob).to have_received(:perform_later).with(1, 'telegram_booking_cancelled')
        expect(BookingNotificationJob).to have_received(:perform_later).with(1, 'partner_booking_cancelled', 'partner@test.com')
        expect(BookingNotificationJob).to have_received(:perform_later).with(1, 'push_partner_booking_cancelled')
        expect(BookingNotificationJob).to have_received(:perform_later).with(1, 'telegram_partner_booking_cancelled')
      end
    end

    context 'when booking status changes to confirmed' do
      it 'dispatches confirmed notification' do
        booking = build_booking(saved_changes: { 'status' => ['pending', 'confirmed'] })

        result = described_class.call(booking)

        expect(result).to eq(:booking_confirmed)
        expect(BookingNotificationJob).to have_received(:perform_later).with(1, 'booking_confirmed')
      end
    end

    context 'when booking status changes to completed' do
      it 'dispatches service_completed notification' do
        booking = build_booking(saved_changes: { 'status' => ['in_progress', 'completed'] })

        result = described_class.call(booking)

        expect(result).to eq(:booking_completed)
        expect(BookingNotificationJob).to have_received(:perform_later).with(1, 'service_completed')
      end
    end

    context 'when time changes' do
      it 'dispatches time change notifications' do
        booking = build_booking(saved_changes: { 'start_time' => ['10:00', '11:00'] })

        result = described_class.call(booking)

        expect(result).to eq(:booking_time_changed)
        expect(BookingNotificationJob).to have_received(:perform_later).with(1, 'booking_time_changed')
        expect(BookingNotificationJob).to have_received(:perform_later).with(1, 'admin_booking_changed', 'admin@test.com')
        expect(BookingNotificationJob).to have_received(:perform_later).with(1, 'telegram_booking_time_changed')
      end
    end

    context 'when location changes' do
      it 'dispatches location change notifications' do
        booking = build_booking(saved_changes: { 'service_point_id' => [1, 2] })

        result = described_class.call(booking)

        expect(result).to eq(:booking_location_changed)
        expect(BookingNotificationJob).to have_received(:perform_later).with(1, 'booking_location_changed')
        expect(BookingNotificationJob).to have_received(:perform_later).with(1, 'admin_booking_changed', 'admin@test.com')
        expect(BookingNotificationJob).to have_received(:perform_later).with(1, 'telegram_booking_location_changed')
      end
    end

    context 'when client info changes' do
      it 'dispatches client info change notifications' do
        booking = build_booking(saved_changes: { 'service_recipient_phone' => ['+380111', '+380222'] })

        result = described_class.call(booking)

        expect(result).to eq(:booking_client_info_changed)
        expect(BookingNotificationJob).to have_received(:perform_later).with(1, 'booking_client_info_changed')
        expect(BookingNotificationJob).to have_received(:perform_later).with(1, 'admin_booking_changed', 'admin@test.com')
      end
    end

    context 'when no event is detected' do
      it 'returns nil and dispatches nothing' do
        booking = build_booking(saved_changes: { 'total_price' => [100, 200] })

        result = described_class.call(booking)

        expect(result).to be_nil
        expect(BookingNotificationJob).not_to have_received(:perform_later)
      end
    end

    context 'deduplication: one save = max one event' do
      it 'dispatches only the highest-priority event notifications' do
        booking = build_booking(
          saved_changes: {
            'status' => ['confirmed', 'cancelled_by_client'],
            'start_time' => ['10:00', '11:00'],
            'service_recipient_phone' => ['+380111', '+380222']
          }
        )
        allow(service_point).to receive(:active_operators).and_return([])

        result = described_class.call(booking)

        expect(result).to eq(:booking_cancelled)
        # Should NOT dispatch time_changed or client_info_changed notifications
        expect(BookingNotificationJob).not_to have_received(:perform_later).with(1, 'booking_time_changed')
        expect(BookingNotificationJob).not_to have_received(:perform_later).with(1, 'booking_client_info_changed')
      end
    end

    context 'when partner has no user' do
      it 'skips partner notifications gracefully' do
        no_user_partner = instance_double(Partner, user: nil)
        allow(service_point).to receive(:partner).and_return(no_user_partner)

        booking = build_booking(previously_new_record: true)
        allow(service_point).to receive(:active_operators).and_return([])

        # Should not raise
        expect { described_class.call(booking) }.not_to raise_error

        # Partner-specific notifications should not be called
        expect(BookingNotificationJob).not_to have_received(:perform_later).with(1, 'partner_new_booking', anything)
      end
    end
  end

  describe 'EVENT_PRIORITY' do
    it 'contains all events from STATUS_EVENT_MAP' do
      status_events = described_class::STATUS_EVENT_MAP.values.uniq
      status_events.each do |event|
        expect(described_class::EVENT_PRIORITY).to include(event)
      end
    end

    it 'contains all events from ROUTING_MATRIX' do
      routing_events = described_class::ROUTING_MATRIX.keys
      routing_events.each do |event|
        expect(described_class::EVENT_PRIORITY).to include(event)
      end
    end
  end

  describe 'ROUTING_MATRIX' do
    it 'has an entry for every event in EVENT_PRIORITY' do
      described_class::EVENT_PRIORITY.each do |event|
        expect(described_class::ROUTING_MATRIX).to have_key(event),
          "ROUTING_MATRIX missing key for event #{event}"
      end
    end
  end
end
