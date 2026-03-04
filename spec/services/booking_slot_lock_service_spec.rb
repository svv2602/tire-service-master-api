# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BookingSlotLockService do
  let!(:region) { create(:region, name: 'Киевская область') }
  let!(:city) { create(:city, name: 'Киев', region: region) }
  let!(:partner) { create(:partner, :with_new_user) }
  let!(:service_point) do
    create(:service_point,
           name: 'Test Service Point',
           city: city,
           partner: partner,
           is_active: true,
           work_status: 'working',
           post_count: 2)
  end
  let!(:car_type) { create(:car_type, name: 'Седан') }
  let!(:booking_status) { create(:booking_status, name: 'pending') }

  let(:tomorrow) { Date.current + 1.day }

  let(:booking_attrs) do
    {
      service_point_id: service_point.id,
      booking_date: tomorrow,
      start_time: '10:00',
      car_type_id: car_type.id,
      status: 'pending',
      service_recipient_first_name: 'Test',
      service_recipient_last_name: 'User',
      service_recipient_phone: '+380671234567'
    }
  end

  describe '.call' do
    context 'when slot is available' do
      it 'creates a booking successfully' do
        result = described_class.call(
          service_point_id: service_point.id,
          booking_date: tomorrow,
          start_time: '10:00',
          booking_attrs: booking_attrs,
          skip_availability: true # Skip DynamicAvailabilityService for unit test
        )

        expect(result).to be_success
        expect(result.data[:booking]).to be_a(Booking)
        expect(result.data[:booking]).to be_persisted
        expect(result.data[:booking].service_point_id).to eq(service_point.id)
        expect(result.data[:booking].booking_date).to eq(tomorrow)
      end
    end

    context 'when booking attrs are invalid' do
      it 'returns validation error' do
        invalid_attrs = booking_attrs.merge(service_point_id: nil)

        result = described_class.call(
          service_point_id: service_point.id,
          booking_date: tomorrow,
          start_time: '10:00',
          booking_attrs: invalid_attrs,
          skip_availability: true
        )

        expect(result).not_to be_success
        expect(result.data[:error_type]).to eq(:validation_error)
      end
    end

    context 'when database unique constraint is violated' do
      it 'returns db_conflict error' do
        # Simulate RecordNotUnique by stubbing Booking.new to raise
        allow_any_instance_of(Booking).to receive(:save).and_raise(
          ActiveRecord::RecordNotUnique.new('duplicate key value violates unique constraint')
        )

        result = described_class.call(
          service_point_id: service_point.id,
          booking_date: tomorrow,
          start_time: '10:00',
          booking_attrs: booking_attrs,
          skip_availability: true
        )

        expect(result).not_to be_success
        expect(result.data[:error_type]).to eq(:db_conflict)
      end
    end

    # Race condition test: multiple threads try to book the same slot simultaneously.
    # Only one should succeed; all others should get a conflict or lock-based rejection.
    #
    # NOTE: This test requires use_transactional_fixtures = false or a special setup
    # because transactional fixtures wrap each example in a transaction that is invisible
    # to other threads/connections. The test is structured as a scaffold that demonstrates
    # the pattern; in CI with proper database setup it will verify the race condition fix.
    context 'race condition prevention (scaffold)', skip: 'Requires non-transactional test setup and running DB' do
      it 'allows only one booking when multiple threads compete for the same slot' do
        results = []
        threads = 5.times.map do
          Thread.new do
            # Each thread needs its own database connection
            ActiveRecord::Base.connection_pool.with_connection do
              result = described_class.call(
                service_point_id: service_point.id,
                booking_date: tomorrow,
                start_time: '10:00',
                booking_attrs: booking_attrs.merge(
                  service_recipient_phone: "+3806712345#{rand(10..99)}"
                ),
                skip_availability: true
              )
              result
            end
          end
        end

        results = threads.map(&:value)

        successes = results.count(&:success?)
        failures = results.count { |r| !r.success? }

        # Exactly one booking should succeed
        expect(successes).to eq(1)
        expect(failures).to eq(4)

        # Verify only one booking exists in the database
        booking_count = Booking.where(
          service_point_id: service_point.id,
          booking_date: tomorrow,
          start_time: Time.parse("#{tomorrow} 10:00")
        ).where.not(status: %w[cancelled_by_client cancelled_by_partner no_show]).count

        expect(booking_count).to eq(1)
      end
    end
  end

  describe '#generate_lock_key' do
    it 'generates deterministic lock keys for the same input' do
      service1 = described_class.new(
        service_point_id: 1,
        booking_date: '2026-03-05',
        start_time: '10:00',
        booking_attrs: {},
        skip_availability: true
      )

      service2 = described_class.new(
        service_point_id: 1,
        booking_date: '2026-03-05',
        start_time: '10:00',
        booking_attrs: {},
        skip_availability: true
      )

      key1 = service1.send(:generate_lock_key)
      key2 = service2.send(:generate_lock_key)

      expect(key1).to eq(key2)
    end

    it 'generates different lock keys for different inputs' do
      service1 = described_class.new(
        service_point_id: 1,
        booking_date: '2026-03-05',
        start_time: '10:00',
        booking_attrs: {},
        skip_availability: true
      )

      service2 = described_class.new(
        service_point_id: 1,
        booking_date: '2026-03-05',
        start_time: '11:00',
        booking_attrs: {},
        skip_availability: true
      )

      key1 = service1.send(:generate_lock_key)
      key2 = service2.send(:generate_lock_key)

      expect(key1).not_to eq(key2)
    end
  end
end
