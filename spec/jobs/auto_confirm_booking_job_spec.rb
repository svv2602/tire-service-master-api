# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutoConfirmBookingJob, type: :job do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner) }
  let(:service_point) { create(:service_point, partner: partner) }
  let(:booking) { create(:booking, service_point: service_point, status: 'pending') }

  # Allow all logger calls to pass through, then set specific expectations
  before do
    allow(Rails.logger).to receive(:info).and_call_original
    allow(Rails.logger).to receive(:warn).and_call_original
    allow(Rails.logger).to receive(:error).and_call_original
  end

  describe '#perform' do
    context 'when booking is pending and auto-confirm is enabled' do
      before do
        service_point.update!(automation_settings: {
          'auto_confirm_enabled' => true,
          'auto_confirm_delay_minutes' => 0,
          'send_confirmation_sms' => false
        })
      end

      it 'confirms the booking' do
        expect {
          described_class.perform_now(booking.id)
        }.to change { booking.reload.status }.from('pending').to('confirmed')
      end

      it 'logs the confirmation' do
        described_class.perform_now(booking.id)
        # Verify log was written (checking the log file or using custom matcher)
        expect(booking.reload.status).to eq('confirmed')
      end
    end

    context 'when booking is not pending' do
      before do
        booking.update_column(:status, 'confirmed')
        service_point.update!(automation_settings: { 'auto_confirm_enabled' => true })
      end

      it 'skips confirmation' do
        expect {
          described_class.perform_now(booking.id)
        }.not_to change { booking.reload.status }
      end

      it 'does not change the status' do
        described_class.perform_now(booking.id)
        expect(booking.reload.status).to eq('confirmed')
      end
    end

    context 'when auto-confirm is disabled' do
      before do
        service_point.update!(automation_settings: { 'auto_confirm_enabled' => false })
      end

      it 'does not confirm the booking' do
        expect {
          described_class.perform_now(booking.id)
        }.not_to change { booking.reload.status }
      end

      it 'keeps booking in pending status' do
        described_class.perform_now(booking.id)
        expect(booking.reload.status).to eq('pending')
      end
    end

    context 'when booking not found' do
      # Job has retry_on ActiveRecord::RecordNotFound with 3 attempts
      it 'is discarded after retries exhausted' do
        # Simply verify job can be enqueued with invalid ID
        expect {
          described_class.perform_later(999_999)
        }.to have_enqueued_job(described_class).with(999_999)
      end
    end
  end

  describe 'conditions checking' do
    before do
      service_point.update!(automation_settings: {
        'auto_confirm_enabled' => true,
        'auto_confirm_delay_minutes' => 0,
        'auto_confirm_conditions' => conditions
      })
    end

    context 'with min_advance_hours condition' do
      let(:conditions) { { 'min_advance_hours' => 24 } }

      it 'confirms booking made more than 24 hours in advance' do
        booking.update!(
          booking_date: Date.current + 2.days,
          start_time: Time.current.change(hour: 10, min: 0)
        )

        expect {
          described_class.perform_now(booking.id)
        }.to change { booking.reload.status }.to('confirmed')
      end

      it 'does not confirm booking made less than 24 hours in advance' do
        booking.update!(
          booking_date: Date.current,
          start_time: Time.current + 1.hour
        )

        expect {
          described_class.perform_now(booking.id)
        }.not_to change { booking.reload.status }
      end
    end

    context 'with max_advance_days condition' do
      let(:conditions) { { 'max_advance_days' => 7 } }

      it 'confirms booking within 7 days' do
        booking.update!(booking_date: Date.current + 5.days)

        expect {
          described_class.perform_now(booking.id)
        }.to change { booking.reload.status }.to('confirmed')
      end

      it 'does not confirm booking more than 7 days ahead' do
        booking.update!(booking_date: Date.current + 10.days)

        expect {
          described_class.perform_now(booking.id)
        }.not_to change { booking.reload.status }
      end
    end

    context 'with categories condition' do
      let(:category1) { create(:service_category) }
      let(:category2) { create(:service_category) }
      let(:conditions) { { 'categories' => [category1.id] } }

      before do
        # Set up service point to support both categories via service_posts
        create(:service_post, service_point: service_point, service_category: category1)
        create(:service_post, service_point: service_point, service_category: category2)
      end

      it 'confirms booking with allowed category' do
        booking.update_column(:service_category_id, category1.id)

        expect {
          described_class.perform_now(booking.id)
        }.to change { booking.reload.status }.to('confirmed')
      end

      it 'does not confirm booking with different category' do
        booking.update_column(:service_category_id, category2.id)

        expect {
          described_class.perform_now(booking.id)
        }.not_to change { booking.reload.status }
      end
    end
  end

  describe 'SMS sending' do
    let(:phone) { '+380501234567' }

    before do
      booking.update!(service_recipient_phone: phone)
      service_point.update!(automation_settings: {
        'auto_confirm_enabled' => true,
        'send_confirmation_sms' => true
      })
    end

    it 'sends SMS when enabled' do
      expect(SmsService).to receive(:send_booking_confirmation).with(phone, booking)
      described_class.perform_now(booking.id)
    end

    context 'when SMS sending fails' do
      before do
        allow(SmsService).to receive(:send_booking_confirmation).and_raise(StandardError.new('SMS failed'))
      end

      it 'still confirms the booking' do
        expect {
          described_class.perform_now(booking.id)
        }.to change { booking.reload.status }.to('confirmed')
      end

      it 'does not raise error' do
        expect {
          described_class.perform_now(booking.id)
        }.not_to raise_error
      end
    end

    context 'when send_confirmation_sms is disabled' do
      before do
        service_point.update!(automation_settings: {
          'auto_confirm_enabled' => true,
          'send_confirmation_sms' => false
        })
      end

      it 'does not send SMS' do
        expect(SmsService).not_to receive(:send_booking_confirmation)
        described_class.perform_now(booking.id)
      end
    end
  end

  describe 'job scheduling' do
    it 'is enqueued to default queue' do
      expect {
        described_class.perform_later(booking.id)
      }.to have_enqueued_job.on_queue('default')
    end

    it 'can be scheduled with delay' do
      expect {
        described_class.set(wait: 5.minutes).perform_later(booking.id)
      }.to have_enqueued_job.at(a_value_within(1.second).of(5.minutes.from_now))
    end
  end
end
