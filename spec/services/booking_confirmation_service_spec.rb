# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BookingConfirmationService do
  let!(:region) { create(:region, name: 'Test Region') }
  let!(:city) { create(:city, name: 'Test City', region: region) }
  let!(:partner) { create(:partner, :with_new_user) }
  let!(:service_point) do
    create(:service_point,
           city: city,
           partner: partner,
           is_active: true,
           work_status: 'working')
  end
  let!(:car_type) { create(:car_type, name: 'Sedan') }
  let!(:service_category) { create(:service_category) }

  # Default: client booking (regular user)
  let(:client) { create(:client) }

  let(:booking) do
    create(:booking,
           client: client,
           service_point: service_point,
           car_type: car_type,
           status: 'pending',
           skip_notifications: true,
           skip_availability_check: true)
  end

  describe '.call' do
    context 'when booking is already confirmed' do
      let(:confirmed_booking) do
        create(:booking,
               client: client,
               service_point: service_point,
               car_type: car_type,
               status: 'confirmed',
               skip_notifications: true,
               skip_availability_check: true)
      end

      it 'returns skipped result' do
        result = described_class.call(confirmed_booking)

        expect(result).to be_success
        expect(result).to be_skipped
        expect(result.reason).to eq('booking_already_confirmed')
        expect(confirmed_booking.reload.status).to eq('confirmed')
      end
    end

    context 'when booking is created by admin' do
      let(:admin_user) { create(:admin) }
      let(:admin_client) { create(:client, user: admin_user) }
      let(:admin_booking) do
        create(:booking,
               client: admin_client,
               service_point: service_point,
               car_type: car_type,
               status: 'pending',
               skip_notifications: true,
               skip_availability_check: true)
      end

      it 'confirms immediately' do
        result = described_class.call(admin_booking)

        expect(result).to be_success
        expect(result).to be_confirmed
        expect(result.reason).to eq('admin_or_partner_booking')
        expect(admin_booking.reload.status).to eq('confirmed')
      end
    end

    context 'when booking is created by partner' do
      let(:partner_user) { create(:partner_user) }
      let(:partner_client) { create(:client, user: partner_user) }
      let(:partner_booking) do
        create(:booking,
               client: partner_client,
               service_point: service_point,
               car_type: car_type,
               status: 'pending',
               skip_notifications: true,
               skip_availability_check: true)
      end

      it 'confirms immediately' do
        result = described_class.call(partner_booking)

        expect(result).to be_success
        expect(result).to be_confirmed
        expect(result.reason).to eq('admin_or_partner_booking')
        expect(partner_booking.reload.status).to eq('confirmed')
      end
    end

    context 'when service point has auto_confirm_enabled with delay = 0' do
      before do
        service_point.update!(automation_settings: {
          'auto_confirm_enabled' => true,
          'auto_confirm_delay_minutes' => 0
        })
      end

      it 'confirms immediately' do
        result = described_class.call(booking)

        expect(result).to be_success
        expect(result).to be_confirmed
        expect(result.reason).to eq('service_point_auto_confirm_enabled')
        expect(booking.reload.status).to eq('confirmed')
      end
    end

    context 'when service point has auto_confirm_enabled with delay > 0' do
      before do
        service_point.update!(automation_settings: {
          'auto_confirm_enabled' => true,
          'auto_confirm_delay_minutes' => 10
        })
      end

      it 'schedules delayed confirmation via AutoConfirmBookingJob' do
        expect(AutoConfirmBookingJob).to receive_message_chain(:set, :perform_later)

        result = described_class.call(booking)

        expect(result).to be_success
        expect(result).to be_scheduled
        expect(result.reason).to eq('delayed_confirmation_10_minutes')
        # Status should remain pending (will be changed by the job later)
        expect(booking.reload.status).to eq('pending')
      end
    end

    context 'when category auto-confirmation is enabled' do
      before do
        ServicePointCategorySetting.set_auto_confirmation(
          service_point.id,
          service_category.id,
          true
        )
      end

      let(:booking_with_category) do
        create(:booking,
               client: client,
               service_point: service_point,
               car_type: car_type,
               service_category: service_category,
               status: 'pending',
               skip_notifications: true,
               skip_availability_check: true)
      end

      it 'confirms immediately' do
        result = described_class.call(booking_with_category)

        expect(result).to be_success
        expect(result).to be_confirmed
        expect(result.reason).to eq('category_auto_confirmation_enabled')
        expect(booking_with_category.reload.status).to eq('confirmed')
      end
    end

    context 'when all auto-confirm options are disabled' do
      it 'keeps booking pending' do
        result = described_class.call(booking)

        expect(result).to be_success
        expect(result).to be_pending
        expect(result.reason).to eq('auto_confirm_disabled')
        expect(booking.reload.status).to eq('pending')
      end
    end

    context 'when category auto-confirmation is disabled for the booking category' do
      before do
        ServicePointCategorySetting.set_auto_confirmation(
          service_point.id,
          service_category.id,
          false
        )
      end

      let(:booking_with_disabled_category) do
        create(:booking,
               client: client,
               service_point: service_point,
               car_type: car_type,
               service_category: service_category,
               status: 'pending',
               skip_notifications: true,
               skip_availability_check: true)
      end

      it 'keeps booking pending' do
        result = described_class.call(booking_with_disabled_category)

        expect(result).to be_success
        expect(result).to be_pending
        expect(result.reason).to eq('auto_confirm_disabled')
      end
    end

    context 'when booking has no service category' do
      it 'keeps booking pending (no category to check)' do
        result = described_class.call(booking)

        expect(result).to be_success
        expect(result).to be_pending
        expect(result.reason).to eq('auto_confirm_disabled')
      end
    end

    context 'when guest booking (no client)' do
      let(:guest_booking) do
        create(:booking,
               client: nil,
               service_point: service_point,
               car_type: car_type,
               status: 'pending',
               skip_notifications: true,
               skip_availability_check: true)
      end

      it 'keeps booking pending (no user to determine role)' do
        result = described_class.call(guest_booking)

        expect(result).to be_success
        expect(result).to be_pending
        expect(result.reason).to eq('auto_confirm_disabled')
      end

      context 'with auto_confirm_enabled on service point' do
        before do
          service_point.update!(automation_settings: {
            'auto_confirm_enabled' => true,
            'auto_confirm_delay_minutes' => 0
          })
        end

        it 'confirms immediately (auto-confirm works for any booking type)' do
          result = described_class.call(guest_booking)

          expect(result).to be_success
          expect(result).to be_confirmed
          expect(result.reason).to eq('service_point_auto_confirm_enabled')
        end
      end
    end

    context 'SMS notifications' do
      before do
        service_point.update!(automation_settings: {
          'auto_confirm_enabled' => true,
          'auto_confirm_delay_minutes' => 0,
          'send_confirmation_sms' => true
        })
      end

      it 'sends confirmation SMS when enabled' do
        expect(SmsService).to receive(:send_booking_confirmation)
          .with(booking.service_recipient_phone, booking)

        described_class.call(booking)
      end
    end

    context 'SMS notifications disabled' do
      before do
        service_point.update!(automation_settings: {
          'auto_confirm_enabled' => true,
          'auto_confirm_delay_minutes' => 0,
          'send_confirmation_sms' => false
        })
      end

      it 'does not send confirmation SMS when disabled' do
        expect(SmsService).not_to receive(:send_booking_confirmation)

        described_class.call(booking)
      end
    end

    context 'decision priority: admin booking takes precedence over disabled auto-confirm' do
      let(:admin_user) { create(:admin) }
      let(:admin_client) { create(:client, user: admin_user) }
      let(:admin_booking) do
        create(:booking,
               client: admin_client,
               service_point: service_point,
               car_type: car_type,
               status: 'pending',
               skip_notifications: true,
               skip_availability_check: true)
      end

      before do
        # Explicitly disable auto-confirm
        service_point.update!(automation_settings: {
          'auto_confirm_enabled' => false
        })
      end

      it 'still confirms admin booking even if auto-confirm is globally disabled' do
        result = described_class.call(admin_booking)

        expect(result).to be_success
        expect(result).to be_confirmed
        expect(result.reason).to eq('admin_or_partner_booking')
      end
    end

    context 'decision priority: service point auto-confirm takes precedence over category' do
      before do
        # Enable global auto-confirm with delay
        service_point.update!(automation_settings: {
          'auto_confirm_enabled' => true,
          'auto_confirm_delay_minutes' => 5
        })

        # Also enable category auto-confirm
        ServicePointCategorySetting.set_auto_confirmation(
          service_point.id,
          service_category.id,
          true
        )
      end

      let(:booking_with_category) do
        create(:booking,
               client: client,
               service_point: service_point,
               car_type: car_type,
               service_category: service_category,
               status: 'pending',
               skip_notifications: true,
               skip_availability_check: true)
      end

      it 'uses service point delay over category immediate confirm' do
        expect(AutoConfirmBookingJob).to receive_message_chain(:set, :perform_later)

        result = described_class.call(booking_with_category)

        expect(result).to be_success
        expect(result).to be_scheduled
        expect(result.reason).to eq('delayed_confirmation_5_minutes')
      end
    end

    context 'error handling' do
      it 'returns error result when an exception occurs' do
        # Force an error by stubbing
        allow(booking).to receive(:status).and_raise(StandardError.new('test error'))

        result = described_class.call(booking)

        expect(result).not_to be_success
        expect(result.decision).to eq(:error)
        expect(result.error).to eq('test error')
      end
    end
  end

  describe 'Result struct' do
    it 'correctly identifies confirmed results' do
      result = BookingConfirmationService::Result.new(
        success: true, decision: :confirmed, reason: 'test'
      )
      expect(result).to be_confirmed
      expect(result).not_to be_pending
      expect(result).not_to be_scheduled
      expect(result).not_to be_skipped
    end

    it 'correctly identifies scheduled results' do
      result = BookingConfirmationService::Result.new(
        success: true, decision: :scheduled, reason: 'test'
      )
      expect(result).to be_scheduled
      expect(result).not_to be_confirmed
    end

    it 'correctly identifies pending results' do
      result = BookingConfirmationService::Result.new(
        success: true, decision: :pending, reason: 'test'
      )
      expect(result).to be_pending
      expect(result).not_to be_confirmed
    end

    it 'correctly identifies skipped results' do
      result = BookingConfirmationService::Result.new(
        success: true, decision: :skipped, reason: 'test'
      )
      expect(result).to be_skipped
      expect(result).not_to be_confirmed
    end
  end
end
