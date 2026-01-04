# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Partner Dashboard API', type: :request do
  let(:partner_role) { UserRole.find_or_create_by!(name: 'partner') }
  let(:admin_role) { UserRole.find_or_create_by!(name: 'admin') }
  let(:client_role) { UserRole.find_or_create_by!(name: 'client') }

  let(:partner_user) { create(:user, role: partner_role) }
  let(:partner) { create(:partner, user: partner_user) }
  let(:service_point) { create(:service_point, partner: partner) }

  let(:admin_user) { create(:user, role: admin_role) }

  let(:partner_headers) { auth_headers(partner_user) }
  let(:admin_headers) { auth_headers(admin_user) }

  describe 'GET /api/v1/partners/:partner_id/dashboard' do
    let(:endpoint) { "/api/v1/partners/#{partner.id}/dashboard" }

    context 'when authenticated as partner' do
      it 'returns dashboard data' do
        get endpoint, headers: partner_headers

        expect(response).to have_http_status(:ok)
        expect(json_response).to include(
          :today_bookings,
          :pending_count,
          :weekly_stats,
          :top_services,
          :recent_reviews,
          :quick_stats
        )
      end

      it 'returns today_bookings as array' do
        get endpoint, headers: partner_headers

        expect(json_response[:today_bookings]).to be_an(Array)
      end

      it 'returns pending_count as integer' do
        get endpoint, headers: partner_headers

        expect(json_response[:pending_count]).to be_an(Integer)
      end

      it 'returns weekly_stats with expected keys' do
        get endpoint, headers: partner_headers

        expect(json_response[:weekly_stats]).to include(
          :total_bookings,
          :completed_bookings,
          :cancelled_bookings,
          :pending_bookings,
          :revenue,
          :average_rating,
          :bookings_by_day
        )
      end

      it 'returns quick_stats with expected keys' do
        get endpoint, headers: partner_headers

        expect(json_response[:quick_stats]).to include(
          :total_service_points,
          :active_service_points,
          :total_operators,
          :average_rating,
          :total_clients_served
        )
      end
    end

    context 'with bookings' do
      let!(:today_booking) do
        create(:booking,
               service_point: service_point,
               booking_date: Date.current,
               status: 'pending')
      end

      let!(:yesterday_booking) do
        create(:booking,
               service_point: service_point,
               booking_date: Date.yesterday,
               status: 'completed')
      end

      it 'includes today bookings' do
        get endpoint, headers: partner_headers

        expect(json_response[:today_bookings].length).to eq(1)
        expect(json_response[:today_bookings].first[:id]).to eq(today_booking.id)
      end

      it 'counts pending bookings' do
        get endpoint, headers: partner_headers

        expect(json_response[:pending_count]).to eq(1)
      end

      it 'includes booking in weekly stats' do
        get endpoint, headers: partner_headers

        expect(json_response[:weekly_stats][:total_bookings]).to be >= 1
      end
    end

    context 'with reviews' do
      let!(:review) do
        create(:review,
               service_point: service_point,
               rating: 5,
               status: 'published')
      end

      it 'includes recent reviews' do
        get endpoint, headers: partner_headers

        expect(json_response[:recent_reviews].length).to eq(1)
        expect(json_response[:recent_reviews].first[:rating]).to eq(5)
      end
    end

    context 'when authenticated as admin' do
      it 'can access any partner dashboard' do
        get endpoint, headers: admin_headers

        expect(response).to have_http_status(:ok)
        expect(json_response).to include(:today_bookings)
      end
    end

    context 'when authenticated as client' do
      let(:client_user) { create(:user, role: client_role) }
      let(:client_headers) { auth_headers(client_user) }

      it 'denies access' do
        get endpoint, headers: client_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get endpoint

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when partner not found' do
      it 'returns not found for non-existent partner' do
        get '/api/v1/partners/999999/dashboard', headers: admin_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with caching' do
      it 'caches dashboard data' do
        # First request
        get endpoint, headers: partner_headers
        expect(response).to have_http_status(:ok)

        # Second request should use cache
        expect(Rails.cache).to receive(:fetch).at_least(:once).and_call_original
        get endpoint, headers: partner_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'booking serialization' do
      let!(:booking) do
        create(:booking,
               service_point: service_point,
               booking_date: Date.current,
               start_time: '10:00',
               end_time: '11:00',
               status: 'confirmed',
               car_brand: 'Toyota',
               car_model: 'Camry',
               license_plate: 'AA1234BB',
               service_recipient_first_name: 'Иван',
               service_recipient_last_name: 'Петров',
               service_recipient_phone: '+380501234567')
      end

      it 'serializes booking with all fields' do
        get endpoint, headers: partner_headers

        booking_data = json_response[:today_bookings].first
        expect(booking_data).to include(
          :id,
          :booking_date,
          :start_time,
          :end_time,
          :status,
          :client_name,
          :client_phone,
          :service_point_name,
          :total_price,
          :car_info
        )
        expect(booking_data[:client_name]).to eq('Иван Петров')
        expect(booking_data[:car_info]).to include('Toyota Camry')
        expect(booking_data[:car_info]).to include('AA1234BB')
      end
    end
  end
end
