# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::ClientBookings', type: :request do
  let!(:region) { create(:region, name: 'Kyiv Oblast') }
  let!(:city) { create(:city, name: 'Kyiv', region: region) }
  let!(:partner) { create(:partner, :with_new_user) }
  let!(:car_type) { create(:car_type, name: 'Sedan') }
  let!(:service_category) { create(:service_category) }

  # Service point with proper working_hours JSON for DynamicAvailabilityService
  let!(:service_point) do
    create(:service_point,
           name: 'Test Tire Service',
           city: city,
           partner: partner,
           is_active: true,
           work_status: 'working',
           post_count: 4,
           working_hours: {
             'monday' => { 'is_working_day' => true, 'start' => '09:00', 'end' => '18:00' },
             'tuesday' => { 'is_working_day' => true, 'start' => '09:00', 'end' => '18:00' },
             'wednesday' => { 'is_working_day' => true, 'start' => '09:00', 'end' => '18:00' },
             'thursday' => { 'is_working_day' => true, 'start' => '09:00', 'end' => '18:00' },
             'friday' => { 'is_working_day' => true, 'start' => '09:00', 'end' => '18:00' },
             'saturday' => { 'is_working_day' => true, 'start' => '10:00', 'end' => '16:00' },
             'sunday' => { 'is_working_day' => false, 'start' => '00:00', 'end' => '00:00' }
           })
  end

  # Active service posts required by DynamicAvailabilityService
  let!(:service_posts) do
    4.times.map do |i|
      create(:service_post,
             service_point: service_point,
             service_category: service_category,
             post_number: i + 1,
             slot_duration: 60,
             is_active: true,
             has_custom_schedule: false)
    end
  end

  # Pick the next Monday (a working day) for reliable test dates
  let(:working_day) do
    date = Date.current + 1
    date += 1 until date.wday == 1 # Monday
    date
  end

  describe 'POST /api/v1/client_bookings' do
    let(:valid_params) do
      {
        booking: {
          service_point_id: service_point.id,
          booking_date: working_day.to_s,
          start_time: '10:00',
          car_type_id: car_type.id,
          notes: 'Summer tire replacement',
          service_recipient_first_name: 'Ivan',
          service_recipient_last_name: 'Ivanov',
          service_recipient_phone: '+380671234567',
          service_recipient_email: 'ivan@example.com',
          license_plate: 'AA1234BB',
          car_brand: 'Toyota',
          car_model: 'Camry'
        }
      }
    end

    context 'with valid guest booking data' do
      it 'creates a new booking and returns 201' do
        expect {
          post '/api/v1/client_bookings', params: valid_params, as: :json
        }.to change(Booking, :count).by(1)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['booking_date']).to eq(working_day.to_s)
        expect(body['start_time']).to eq('10:00')
        expect(body['status']['name']).to eq('pending')
      end
    end

    context 'with missing required service_recipient fields' do
      it 'returns unprocessable_entity when service_recipient_first_name is blank' do
        invalid_params = valid_params.deep_dup
        invalid_params[:booking][:service_recipient_first_name] = ''

        post '/api/v1/client_bookings', params: invalid_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body['details']).to be_an(Array)
      end

      it 'returns unprocessable_entity when service_recipient_phone is blank' do
        invalid_params = valid_params.deep_dup
        invalid_params[:booking][:service_recipient_phone] = ''

        post '/api/v1/client_bookings', params: invalid_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body['details']).to be_an(Array)
      end
    end
  end

  describe 'POST /api/v1/client_bookings/check_availability_for_booking' do
    let(:check_params) do
      {
        service_point_id: service_point.id,
        date: working_day.to_s,
        time: '10:00',
        duration_minutes: 60
      }
    end

    it 'returns availability for a free time slot' do
      post '/api/v1/client_bookings/check_availability_for_booking', params: check_params, as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['available']).to be true
      expect(body['service_point_id']).to eq(service_point.id)
    end

    it 'returns unavailable when all posts are occupied' do
      # Create bookings that fill all posts at the target time
      service_posts.each do
        create(:booking,
               service_point: service_point,
               booking_date: working_day,
               start_time: '10:00',
               end_time: '11:00',
               status: 'pending')
      end

      post '/api/v1/client_bookings/check_availability_for_booking', params: check_params, as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['available']).to be false
    end

    it 'returns bad_request when service_point_id is missing' do
      post '/api/v1/client_bookings/check_availability_for_booking', params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
      body = JSON.parse(response.body)
      expect(body['error']).to eq('service_point_id обязателен')
    end
  end

  describe 'GET /api/v1/client_bookings/:id' do
    let!(:client) { create(:client) }
    let!(:booking) do
      create(:booking,
             client: client,
             service_point: service_point,
             car_type: car_type,
             status: 'pending')
    end

    it 'returns booking details' do
      get "/api/v1/client_bookings/#{booking.id}", as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['id']).to eq(booking.id)
      expect(body['status']['name']).to eq('pending')
      expect(body['service_point']['name']).to eq(service_point.name)
    end

    it 'returns 404 for non-existing booking' do
      get '/api/v1/client_bookings/999999', as: :json

      expect(response).to have_http_status(:not_found)
      body = JSON.parse(response.body)
      expect(body['error']).to eq('Запись не найдена')
    end
  end

  describe 'PUT /api/v1/client_bookings/:id' do
    let!(:client) { create(:client) }
    let!(:booking) do
      create(:booking,
             client: client,
             service_point: service_point,
             car_type: car_type,
             status: 'pending',
             booking_date: working_day,
             start_time: '10:00',
             end_time: '11:00')
    end

    it 'updates notes for a pending booking' do
      put "/api/v1/client_bookings/#{booking.id}",
          params: { booking: { notes: 'Updated notes' } },
          as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['notes']).to eq('Updated notes')
    end

    it 'forbids updating a confirmed booking' do
      booking.update_column(:status, 'confirmed')

      put "/api/v1/client_bookings/#{booking.id}",
          params: { booking: { notes: 'New notes' } },
          as: :json

      expect(response).to have_http_status(:forbidden)
      body = JSON.parse(response.body)
      expect(body['error']).to include('нельзя изменить')
    end
  end

  describe 'POST /api/v1/client_bookings/:id/cancel' do
    let!(:client) { create(:client) }

    context 'with a pending booking far in the future' do
      let!(:booking) do
        create(:booking,
               client: client,
               service_point: service_point,
               car_type: car_type,
               status: 'pending',
               booking_date: working_day,
               start_time: '10:00',
               end_time: '11:00')
      end

      it 'cancels the booking' do
        post "/api/v1/client_bookings/#{booking.id}/cancel", as: :json

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['status']['name']).to eq('cancelled_by_client')
        expect(booking.reload.status).to eq('cancelled_by_client')
      end
    end

    context 'when booking is too close to start time' do
      let!(:booking) do
        create(:booking,
               client: client,
               service_point: service_point,
               car_type: car_type,
               status: 'pending',
               booking_date: Date.current,
               start_time: (Time.current + 30.minutes).strftime('%H:%M'),
               end_time: (Time.current + 90.minutes).strftime('%H:%M'))
      end

      it 'returns forbidden' do
        post "/api/v1/client_bookings/#{booking.id}/cancel", as: :json

        expect(response).to have_http_status(:forbidden)
        body = JSON.parse(response.body)
        expect(body['reason']).to be_present
      end
    end
  end

  describe 'POST /api/v1/client_bookings/:id/reschedule' do
    let!(:client) { create(:client) }
    let!(:booking) do
      create(:booking,
             client: client,
             service_point: service_point,
             car_type: car_type,
             status: 'pending',
             booking_date: working_day,
             start_time: '10:00',
             end_time: '11:00')
    end

    # Pick a second working day (next Monday after working_day)
    let(:new_working_day) { working_day + 7 }

    it 'reschedules the booking to new time' do
      post "/api/v1/client_bookings/#{booking.id}/reschedule",
           params: { new_date: new_working_day.to_s, new_time: '14:00' },
           as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['booking_date']).to eq(new_working_day.to_s)
      expect(body['start_time']).to eq('14:00')
    end

    it 'returns bad_request when new_date is missing' do
      post "/api/v1/client_bookings/#{booking.id}/reschedule",
           params: {},
           as: :json

      expect(response).to have_http_status(:bad_request)
      body = JSON.parse(response.body)
      expect(body['error']).to eq('new_date обязательна')
    end

    it 'returns unprocessable_entity when new time is unavailable' do
      # Fill all posts at the target time
      service_posts.each do
        create(:booking,
               service_point: service_point,
               booking_date: new_working_day,
               start_time: '14:00',
               end_time: '15:00',
               status: 'pending')
      end

      post "/api/v1/client_bookings/#{booking.id}/reschedule",
           params: { new_date: new_working_day.to_s, new_time: '14:00' },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body['error']).to eq('Новое время недоступно')
    end
  end
end
