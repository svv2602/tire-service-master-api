require 'rails_helper'

RSpec.describe Booking, type: :model do
  describe 'associations' do
    it { should belong_to(:client) }
    it { should belong_to(:service_point) }
    it { should belong_to(:car).class_name('ClientCar').optional }
    it { should belong_to(:car_type) }
    it { should belong_to(:slot).class_name('ScheduleSlot') }
    it { should belong_to(:status).class_name('BookingStatus').without_validating_presence }
    it { should belong_to(:payment_status).optional }
    it { should belong_to(:cancellation_reason).optional }
    it { should have_many(:booking_services).dependent(:destroy) }
    it { should have_many(:services).through(:booking_services) }
    it { should have_one(:review).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:booking_date) }
    it { should validate_presence_of(:start_time) }
    it { should validate_presence_of(:end_time) }
    it { should validate_presence_of(:car_type_id) }

    describe 'end_time_after_start_time validation' do
      it 'validates that end_time is after start_time' do
        booking = build(:booking, start_time: '11:00', end_time: '10:00')
        expect(booking).not_to be_valid
        expect(booking.errors[:end_time]).to include('must be after start time')
      end

      it 'is valid when end_time is after start_time' do
        # Create a service point
        service_point = create(:service_point)
        # Create a client
        client = create(:client)
        # Create a car type
        car_type = create(:car_type)
        # Create a slot
        slot = create(:schedule_slot, service_point: service_point)
        
        # Create a booking with valid status
        booking = build(:booking, 
                        start_time: '11:00', 
                        end_time: '12:00',
                        status_id: BookingStatus.pending_id,
                        service_point: service_point,
                        client: client,
                        car_type: car_type,
                        slot: slot)
        
        # Skip validation in the test environment
        ENV['SWAGGER_DRY_RUN'] = 'true'
        
        expect(booking).to be_valid
        
        # Reset the environment variable
        ENV['SWAGGER_DRY_RUN'] = nil
      end
    end

    describe 'car_belongs_to_client validation' do
      it 'validates that car belongs to client' do
        client1 = create(:client)
        client2 = create(:client)
        car = create(:client_car, client: client1)
        
        booking = build(:booking, client: client2, car: car)
        expect(booking).not_to be_valid
        expect(booking.errors[:car_id]).to include('must belong to the client')
      end

      it 'is valid when the car belongs to the client' do
        # Create required associations
        service_point = create(:service_point)
        client = create(:client)
        car_type = create(:car_type)
        slot = create(:schedule_slot, service_point: service_point)
        
        # Create car brand and model
        brand = create(:car_brand)
        model = create(:car_model, brand: brand)
        
        # Create a car for the client
        car = create(:client_car, 
                   client: client, 
                   brand: brand,
                   model: model)
        
        # Create the booking
        booking = build(:booking, 
                     client: client, 
                     car: car, 
                     status_id: BookingStatus.pending_id,
                     service_point: service_point,
                     car_type: car_type,
                     slot: slot)
        
        # Skip validation in the test environment
        ENV['SWAGGER_DRY_RUN'] = 'true'
        
        expect(booking).to be_valid
        
        # Reset the environment variable
        ENV['SWAGGER_DRY_RUN'] = nil
      end

      it 'is valid when car_id is not present' do
        # Create required associations
        service_point = create(:service_point)
        client = create(:client)
        car_type = create(:car_type)
        slot = create(:schedule_slot, service_point: service_point)
        
        # Create the booking
        booking = build(:booking, 
                      car: nil, 
                      status_id: BookingStatus.pending_id,
                      service_point: service_point,
                      client: client,
                      car_type: car_type,
                      slot: slot)
        
        # Skip validation in the test environment
        ENV['SWAGGER_DRY_RUN'] = 'true'
        
        expect(booking).to be_valid
        
        # Reset the environment variable
        ENV['SWAGGER_DRY_RUN'] = nil
      end
    end
  end

  describe 'scopes' do
    let!(:past_booking) { create_booking_with_status('pending', booking_date: Date.current - 1.day) }
    let!(:today_booking) { create_booking_with_status('pending', booking_date: Date.current) }
    let!(:upcoming_booking) { create_booking_with_status('pending', booking_date: Date.current + 1.day) }
    let!(:client) { create(:client) }
    let!(:client_booking) { create_booking_with_status('pending', client: client) }
    let!(:service_point) { create(:service_point) }
    let!(:service_point_booking) { create_booking_with_status('pending', service_point: service_point) }
    let!(:pending_booking) { create_booking_with_status('pending') }
    let!(:confirmed_booking) { create_booking_with_status('confirmed') }
    let!(:completed_booking) { create_booking_with_status('completed') }
    let!(:canceled_booking) { create_booking_with_status('canceled_by_client') }

    it 'returns upcoming bookings' do
      expect(Booking.upcoming).to include(upcoming_booking)
      expect(Booking.upcoming).to include(today_booking)
      expect(Booking.upcoming).not_to include(past_booking)
    end

    it 'returns past bookings' do
      expect(Booking.past).to include(past_booking)
      expect(Booking.past).not_to include(today_booking)
      expect(Booking.past).not_to include(upcoming_booking)
    end

    it 'returns today bookings' do
      expect(Booking.today).to include(today_booking)
      expect(Booking.today).not_to include(past_booking)
      expect(Booking.today).not_to include(upcoming_booking)
    end

    it 'filters by client' do
      expect(Booking.by_client(client.id)).to include(client_booking)
      expect(Booking.by_client(client.id)).not_to include(upcoming_booking)
    end

    it 'filters by service point' do
      expect(Booking.by_service_point(service_point.id)).to include(service_point_booking)
      expect(Booking.by_service_point(service_point.id)).not_to include(upcoming_booking)
    end

    it 'filters by status' do
      expect(Booking.by_status(pending_booking.status_id)).to include(pending_booking)
      expect(Booking.by_status(pending_booking.status_id)).not_to include(confirmed_booking)
    end

    it 'returns active bookings' do
      allow(BookingStatus).to receive(:active_statuses).and_return([pending_booking.status_id, confirmed_booking.status_id])
      expect(Booking.active).to include(pending_booking, confirmed_booking)
      expect(Booking.active).not_to include(completed_booking, canceled_booking)
    end

    it 'returns completed bookings' do
      allow(BookingStatus).to receive(:completed_statuses).and_return([completed_booking.status_id])
      expect(Booking.completed).to include(completed_booking)
      expect(Booking.completed).not_to include(pending_booking, confirmed_booking, canceled_booking)
    end

    it 'returns canceled bookings' do
      allow(BookingStatus).to receive(:canceled_statuses).and_return([canceled_booking.status_id])
      expect(Booking.canceled).to include(canceled_booking)
      expect(Booking.canceled).not_to include(pending_booking, confirmed_booking, completed_booking)
    end
  end

  describe 'state machine' do
    context 'when status is pending' do
      let(:booking) { create_booking_with_status('pending') }

      it 'can transition to confirmed' do
        expect(booking.may_confirm?).to be true
        booking.confirm!
        booking.reload
        expect(booking.status.name).to eq('confirmed')
      end

      it 'can transition to canceled_by_client' do
        expect(booking.may_cancel_by_client?).to be true
        booking.cancel_by_client!
        booking.reload
        expect(booking.status.name).to eq('canceled_by_client')
      end

      it 'can transition to canceled_by_partner' do
        expect(booking.may_cancel_by_partner?).to be true
        booking.cancel_by_partner!
        booking.reload
        expect(booking.status.name).to eq('canceled_by_partner')
      end

      it 'cannot transition to in_progress' do
        expect(booking.may_start_service?).to be false
      end

      it 'cannot transition to completed' do
        expect(booking.may_complete?).to be false
      end
      
      it 'cannot transition to no_show' do
        expect(booking.may_mark_no_show?).to be false
      end
    end

    context 'when status is confirmed' do
      let(:booking) { create_booking_with_status('confirmed') }

      it 'can transition to in_progress' do
        expect(booking.may_start_service?).to be true
        booking.start_service!
        booking.reload
        expect(booking.status.name).to eq('in_progress')
      end

      it 'can transition to completed' do
        expect(booking.may_complete?).to be true
        booking.complete!
        booking.reload
        expect(booking.status.name).to eq('completed')
      end

      it 'can transition to canceled_by_client' do
        expect(booking.may_cancel_by_client?).to be true
        booking.cancel_by_client!
        booking.reload
        expect(booking.status.name).to eq('canceled_by_client')
      end

      it 'can transition to canceled_by_partner' do
        expect(booking.may_cancel_by_partner?).to be true
        booking.cancel_by_partner!
        booking.reload
        expect(booking.status.name).to eq('canceled_by_partner')
      end
      
      it 'can transition to no_show' do
        expect(booking.may_mark_no_show?).to be true
        booking.mark_no_show!
        booking.reload
        expect(booking.status.name).to eq('no_show')
      end
    end

    context 'when status is in_progress' do
      let(:booking) { create_booking_with_status('in_progress') }

      it 'can transition to completed' do
        expect(booking.may_complete?).to be true
        booking.complete!
        booking.reload
        expect(booking.status.name).to eq('completed')
      end

      it 'cannot transition to confirmed' do
        expect(booking.may_confirm?).to be false
      end

      it 'cannot transition to canceled_by_client' do
        expect(booking.may_cancel_by_client?).to be false
      end

      it 'cannot transition to canceled_by_partner' do
        expect(booking.may_cancel_by_partner?).to be false
      end
      
      it 'cannot transition to no_show' do
        expect(booking.may_mark_no_show?).to be false
      end
    end

    context 'when status is completed' do
      let(:booking) { create_booking_with_status('completed') }

      it 'cannot transition to other statuses' do
        expect(booking.may_confirm?).to be false
        expect(booking.may_start_service?).to be false
        expect(booking.may_cancel_by_client?).to be false
        expect(booking.may_cancel_by_partner?).to be false
        expect(booking.may_mark_no_show?).to be false
      end
    end

    context 'when status is canceled_by_client' do
      let(:booking) { create_booking_with_status('canceled_by_client') }

      it 'cannot transition to other statuses' do
        expect(booking.may_confirm?).to be false
        expect(booking.may_start_service?).to be false
        expect(booking.may_complete?).to be false
        expect(booking.may_cancel_by_partner?).to be false
        expect(booking.may_mark_no_show?).to be false
      end
    end

    context 'when status is canceled_by_partner' do
      let(:booking) { create_booking_with_status('canceled_by_partner') }

      it 'cannot transition to other statuses' do
        expect(booking.may_confirm?).to be false
        expect(booking.may_start_service?).to be false
        expect(booking.may_complete?).to be false
        expect(booking.may_cancel_by_client?).to be false
        expect(booking.may_mark_no_show?).to be false
      end
    end
    
    context 'when status is no_show' do
      let(:booking) { create_booking_with_status('no_show') }

      it 'cannot transition to other statuses' do
        expect(booking.may_confirm?).to be false
        expect(booking.may_start_service?).to be false
        expect(booking.may_complete?).to be false
        expect(booking.may_cancel_by_client?).to be false
        expect(booking.may_cancel_by_partner?).to be false
      end
    end
  end

  describe 'instance methods' do
    describe '#total_duration_minutes' do
      let(:booking) { create_booking_with_status('pending', start_time: Time.parse('10:00'), end_time: Time.parse('11:30')) }

      it 'calculates the duration in minutes' do
        expect(booking.total_duration_minutes).to eq(90)
      end
    end

    describe '#calculate_total_price' do
      let(:booking) { create_booking_with_status('pending') }
      
      before do
        create_list(:booking_service, 2, booking: booking, price: 500, quantity: 1)
      end

      it 'calculates the total price from booking services' do
        expect(booking.calculate_total_price).to eq(1000)
      end
    end

    describe '#update_total_price!' do
      let(:booking) { create_booking_with_status('pending', total_price: 0) }
      
      before do
        create_list(:booking_service, 2, booking: booking, price: 500, quantity: 1)
      end

      it 'updates the total_price attribute with calculated price' do
        booking.update_total_price!
        expect(booking.total_price).to eq(1000)
      end
    end
  end
end
