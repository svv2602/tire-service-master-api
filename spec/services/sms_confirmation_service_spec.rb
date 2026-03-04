# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SmsConfirmationService do
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

  let(:guest_booking) do
    create(:booking,
           client: nil,
           service_point: service_point,
           car_type: car_type,
           status: 'pending',
           service_recipient_phone: '+380671234567',
           service_recipient_first_name: 'Test',
           service_recipient_last_name: 'Guest',
           skip_notifications: true,
           skip_availability_check: true)
  end

  let(:redis_mock) { instance_double(Redis) }

  before do
    allow(Redis).to receive(:current).and_return(redis_mock)
    allow(redis_mock).to receive(:setex)
    allow(redis_mock).to receive(:del)
    allow(redis_mock).to receive(:get).and_return(nil)
    allow(redis_mock).to receive(:exists?).and_return(false)
    allow(redis_mock).to receive(:incr)
    allow(redis_mock).to receive(:expire)
    allow(redis_mock).to receive(:ttl).and_return(60)
  end

  describe '.send_code' do
    it 'generates and sends an SMS code' do
      allow(SmsService).to receive(:send_sms).and_return({ success: true })

      result = described_class.send_code(guest_booking)

      expect(result.success?).to be true
      expect(result.data[:expires_in]).to eq(600)
      expect(SmsService).to have_received(:send_sms).once
    end

    it 'stores code in Redis with TTL' do
      allow(SmsService).to receive(:send_sms).and_return({ success: true })

      described_class.send_code(guest_booking)

      expect(redis_mock).to have_received(:setex).with(
        "sms_code:+380671234567:#{guest_booking.id}",
        600,
        anything
      )
    end

    it 'returns error when phone is missing' do
      guest_booking.update_column(:service_recipient_phone, nil)

      result = described_class.send_code(guest_booking.reload)

      expect(result.success?).to be false
      expect(result.error).to eq('Phone number is missing')
    end

    it 'respects resend cooldown' do
      allow(redis_mock).to receive(:exists?).and_return(true)

      result = described_class.send_code(guest_booking)

      expect(result.success?).to be false
      expect(result.error).to eq('resend_cooldown')
    end
  end

  describe '.verify_code' do
    let(:code) { '123456' }

    before do
      allow(redis_mock).to receive(:get)
        .with("sms_code:+380671234567:#{guest_booking.id}")
        .and_return(code)
      allow(redis_mock).to receive(:get)
        .with("sms_code:attempts:+380671234567:#{guest_booking.id}")
        .and_return('0')
    end

    it 'confirms booking when code is correct' do
      result = described_class.verify_code(guest_booking, code)

      expect(result.success?).to be true
      expect(guest_booking.reload.sms_confirmed?).to be true
    end

    it 'rejects invalid code' do
      result = described_class.verify_code(guest_booking, 'wrong_code')

      expect(result.success?).to be false
      expect(result.error).to eq('invalid_code')
    end

    it 'returns error when code has expired' do
      allow(redis_mock).to receive(:get)
        .with("sms_code:+380671234567:#{guest_booking.id}")
        .and_return(nil)

      result = described_class.verify_code(guest_booking, code)

      expect(result.success?).to be false
      expect(result.error).to eq('code_expired')
    end

    it 'returns error when max attempts exceeded' do
      allow(redis_mock).to receive(:get)
        .with("sms_code:attempts:+380671234567:#{guest_booking.id}")
        .and_return('5')

      result = described_class.verify_code(guest_booking, code)

      expect(result.success?).to be false
      expect(result.error).to eq('max_attempts_exceeded')
    end
  end

  describe '.requires_confirmation?' do
    it 'returns true for guest booking in pending status' do
      expect(described_class.requires_confirmation?(guest_booking)).to be true
    end

    it 'returns false for client booking' do
      client = create(:client)
      client_booking = create(:booking,
                              client: client,
                              service_point: service_point,
                              car_type: car_type,
                              status: 'pending',
                              skip_notifications: true,
                              skip_availability_check: true)

      expect(described_class.requires_confirmation?(client_booking)).to be false
    end

    it 'returns false when already SMS confirmed' do
      guest_booking.update_column(:sms_confirmed, true)

      expect(described_class.requires_confirmation?(guest_booking.reload)).to be false
    end
  end
end
