require 'rails_helper'

RSpec.describe 'API V1 Operator Bookings', type: :request do
  include ServicePointsTestHelper

  before(:all) do
    BookingStatus.destroy_all if BookingStatus.exists?

    @pending_status = BookingStatus.create!(
      name: 'pending', description: 'Pending', color: '#FFC107', is_active: true, sort_order: 1
    )
    @confirmed_status = BookingStatus.create!(
      name: 'confirmed', description: 'Confirmed', color: '#4CAF50', is_active: true, sort_order: 2
    )
    @in_progress_status = BookingStatus.create!(
      name: 'in_progress', description: 'In progress', color: '#2196F3', is_active: true, sort_order: 3
    )
    @completed_status = BookingStatus.create!(
      name: 'completed', description: 'Completed', color: '#8BC34A', is_active: true, sort_order: 4
    )
    @no_show_status = BookingStatus.create!(
      name: 'no_show', description: 'No show', color: '#607D8B', is_active: true, sort_order: 7
    )
    @canceled_by_client_status = BookingStatus.create!(
      name: 'canceled_by_client', description: 'Canceled by client', color: '#F44336', is_active: true, sort_order: 5
    )
    @canceled_by_partner_status = BookingStatus.create!(
      name: 'canceled_by_partner', description: 'Canceled by partner', color: '#9C27B0', is_active: true, sort_order: 6
    )

    PaymentStatus.find_or_create_by(
      name: 'pending', description: 'Pending', color: '#FFC107', sort_order: 1
    )
  end

  let(:partner_user) { create(:partner_user) }
  let(:service_point) { create(:service_point, partner: partner_user.partner) }
  let(:operator_user) { create(:operator_user) }
  let(:operator) { operator_user.operator }

  # Assign operator to service point
  let!(:operator_assignment) do
    operator.update(partner: partner_user.partner)
    OperatorServicePoint.create!(
      operator: operator,
      service_point: service_point,
      is_active: true
    )
  end

  let(:client_user) { create(:client_user) }
  let(:operator_headers) { generate_auth_headers(operator_user) }
  let(:client_headers) { generate_auth_headers(client_user) }

  # Helper to create bookings with specific statuses
  def create_operator_booking(status_name, attrs = {})
    status = BookingStatus.find_by!(name: status_name)
    car_type = CarType.first || CarType.create!(name: 'Sedan', description: 'Standard sedan', is_active: true)

    create(:booking, {
      client: client_user.client,
      service_point: service_point,
      booking_date: Date.current,
      start_time: '10:00',
      end_time: '11:00',
      status_id: status.id,
      car_type_id: car_type.id
    }.merge(attrs))
  end

  describe 'GET /api/v1/operator/bookings/today' do
    let!(:today_pending) { create_operator_booking('pending') }
    let!(:today_confirmed) { create_operator_booking('confirmed', start_time: '11:00', end_time: '12:00') }
    let!(:yesterday_booking) { create_operator_booking('pending', booking_date: Date.yesterday) }

    context 'as operator' do
      it 'returns today bookings for assigned service points' do
        get '/api/v1/operator/bookings/today', headers: operator_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(2)
        expect(json['stats']).to be_present
        expect(json['stats']['total']).to be >= 2
      end

      it 'filters by status' do
        get '/api/v1/operator/bookings/today', params: { status: 'pending' }, headers: operator_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        json['data'].each do |booking|
          expect(booking['status']).to eq('pending')
        end
      end
    end

    context 'as non-operator' do
      it 'returns 403 forbidden' do
        get '/api/v1/operator/bookings/today', headers: client_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /api/v1/operator/bookings/:id' do
    let!(:booking) { create_operator_booking('confirmed') }

    context 'as operator with access' do
      it 'returns booking details' do
        get "/api/v1/operator/bookings/#{booking.id}", headers: operator_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']['id']).to eq(booking.id)
        expect(json['data']['service_point']['address']).to be_present
      end
    end
  end

  describe 'PATCH /api/v1/operator/bookings/:id/start' do
    let!(:confirmed_booking) { create_operator_booking('confirmed') }

    context 'as operator' do
      it 'transitions booking to in_progress' do
        patch "/api/v1/operator/bookings/#{confirmed_booking.id}/start", headers: operator_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']['status']).to eq('in_progress')
      end
    end

    context 'as non-operator' do
      it 'returns 403 forbidden' do
        patch "/api/v1/operator/bookings/#{confirmed_booking.id}/start", headers: client_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PATCH /api/v1/operator/bookings/:id/complete' do
    let!(:in_progress_booking) { create_operator_booking('in_progress') }

    context 'as operator' do
      it 'transitions booking to completed' do
        patch "/api/v1/operator/bookings/#{in_progress_booking.id}/complete", headers: operator_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']['status']).to eq('completed')
      end
    end
  end

  describe 'PATCH /api/v1/operator/bookings/:id/no_show' do
    let!(:confirmed_booking) { create_operator_booking('confirmed') }

    context 'as operator' do
      it 'marks booking as no_show' do
        patch "/api/v1/operator/bookings/#{confirmed_booking.id}/no_show", headers: operator_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']['status']).to eq('no_show')
      end
    end
  end
end
