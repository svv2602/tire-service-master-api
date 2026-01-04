# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BookingsChannel, type: :channel do
  let(:partner_user) { create(:partner_user) }
  let(:partner) { partner_user.partner }
  let(:service_point) { create(:service_point, partner: partner) }
  let(:client_user) { create(:client_user) }
  let(:valid_token) { Auth::JsonWebToken.encode_access_token(user_id: partner_user.id) }

  before do
    stub_connection(current_user: partner_user)
  end

  describe '#subscribed' do
    context 'with partner user' do
      it 'subscribes to partner bookings stream' do
        subscribe

        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from("bookings:partner_#{partner.id}")
      end
    end

    context 'with non-partner user' do
      before do
        stub_connection(current_user: client_user)
      end

      it 'rejects subscription' do
        subscribe

        expect(subscription).to be_rejected
      end
    end
  end

  describe '#unsubscribed' do
    it 'unsubscribes without errors' do
      subscribe
      expect { subscription.unsubscribe_from_channel }.not_to raise_error
    end
  end

  describe '.broadcast_new_booking' do
    let(:booking) { create(:booking, service_point: service_point, skip_notifications: true) }

    it 'broadcasts to partner channel' do
      expect do
        BookingsChannel.broadcast_new_booking(booking)
      end.to have_broadcasted_to("bookings:partner_#{partner.id}")
        .with(hash_including(type: 'booking_created'))
    end

    it 'includes booking details in broadcast' do
      expect do
        BookingsChannel.broadcast_new_booking(booking)
      end.to have_broadcasted_to("bookings:partner_#{partner.id}")
        .with(hash_including(
                booking: hash_including(
                  id: booking.id,
                  status: booking.status,
                  service_point_id: service_point.id
                )
              ))
    end
  end

  describe '.broadcast_status_change' do
    let(:booking) { create(:booking, service_point: service_point, skip_notifications: true) }

    before do
      booking.update_column(:status, 'confirmed')
    end

    it 'broadcasts status change to partner channel' do
      expect do
        BookingsChannel.broadcast_status_change(booking)
      end.to have_broadcasted_to("bookings:partner_#{partner.id}")
        .with(hash_including(type: 'booking_status_changed'))
    end
  end

  describe '.broadcast_cancellation' do
    let(:booking) { create(:booking, service_point: service_point, skip_notifications: true) }

    before do
      booking.update_column(:status, 'cancelled_by_client')
    end

    it 'broadcasts cancellation to partner channel' do
      expect do
        BookingsChannel.broadcast_cancellation(booking)
      end.to have_broadcasted_to("bookings:partner_#{partner.id}")
        .with(hash_including(type: 'booking_cancelled'))
    end
  end

  describe '.broadcast_update' do
    let(:booking) { create(:booking, service_point: service_point, skip_notifications: true) }

    it 'broadcasts update to partner channel' do
      expect do
        BookingsChannel.broadcast_update(booking)
      end.to have_broadcasted_to("bookings:partner_#{partner.id}")
        .with(hash_including(type: 'booking_updated'))
    end
  end

  describe 'Booking model integration' do
    # Note: after_commit callbacks are tested with skip_notifications = false
    # The callbacks will only run if skip_notifications is not set

    context 'when booking is created' do
      it 'can call broadcast_new_booking method' do
        booking = create(:booking, service_point: service_point,
                                   skip_notifications: true,
                                   skip_availability_check: true)

        # Verify the private method exists and can be called
        expect(booking.private_methods).to include(:broadcast_new_booking)
        expect { booking.send(:broadcast_new_booking) }.not_to raise_error
      end
    end

    context 'when booking status changes' do
      let(:booking) do
        create(:booking, service_point: service_point,
                        skip_notifications: true,
                        skip_availability_check: true)
      end

      before do
        # Enable notifications for the update
        booking.skip_notifications = false
      end

      it 'broadcasts status change event' do
        allow(BookingsChannel).to receive(:broadcast_status_change)

        booking.update!(status: 'confirmed')

        expect(BookingsChannel).to have_received(:broadcast_status_change).with(booking)
      end

      it 'broadcasts cancellation event when cancelled' do
        allow(BookingsChannel).to receive(:broadcast_cancellation)

        booking.update!(status: 'cancelled_by_client')

        expect(BookingsChannel).to have_received(:broadcast_cancellation).with(booking)
      end
    end

    context 'when booking is updated (non-status)' do
      let(:booking) do
        create(:booking, service_point: service_point,
                        skip_notifications: true,
                        skip_availability_check: true)
      end

      before do
        # Enable notifications for the update
        booking.skip_notifications = false
      end

      it 'broadcasts update event' do
        allow(BookingsChannel).to receive(:broadcast_update)

        booking.update!(service_recipient_first_name: 'Updated Name')

        expect(BookingsChannel).to have_received(:broadcast_update).with(booking)
      end
    end
  end
end
