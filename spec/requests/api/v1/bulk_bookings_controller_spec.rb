# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Bulk Bookings API', type: :request do
  let!(:partner) { create(:partner) }
  let!(:partner_user) { create(:user, :partner, partner: partner) }
  let!(:admin_user) { create(:user, :admin) }
  let!(:service_point) { create(:service_point, partner: partner) }

  # Auth headers
  let(:partner_headers) { authenticate_user(partner_user) }
  let(:admin_headers) { authenticate_user(admin_user) }

  # Create bookings in different statuses
  let!(:pending_booking1) { create(:booking, service_point: service_point, status: 'pending') }
  let!(:pending_booking2) { create(:booking, service_point: service_point, status: 'pending') }
  let!(:confirmed_booking) { create(:booking, service_point: service_point, status: 'confirmed') }
  let!(:completed_booking) { create(:booking, service_point: service_point, status: 'completed') }

  describe 'POST /api/v1/partners/:partner_id/bulk_bookings/confirm' do
    let(:valid_params) { { booking_ids: [pending_booking1.id, pending_booking2.id] } }

    context 'when partner is authenticated' do
      it 'confirms multiple pending bookings' do
        post "/api/v1/partners/#{partner.id}/bulk_bookings/confirm",
             params: valid_params,
             headers: partner_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['action']).to eq('confirm')
        expect(json['success_count']).to eq(2)
        expect(json['failed_count']).to eq(0)

        # Verify bookings are confirmed
        expect(pending_booking1.reload.status).to eq('confirmed')
        expect(pending_booking2.reload.status).to eq('confirmed')
      end

      it 'returns errors for bookings that cannot be confirmed' do
        params = { booking_ids: [pending_booking1.id, completed_booking.id] }

        post "/api/v1/partners/#{partner.id}/bulk_bookings/confirm",
             params: params,
             headers: partner_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success_count']).to eq(1)
        expect(json['failed_count']).to eq(1)
        expect(json['failed'].first['error']).to include('Cannot confirm')
      end

      it 'returns error for missing booking_ids' do
        post "/api/v1/partners/#{partner.id}/bulk_bookings/confirm",
             params: {},
             headers: partner_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when admin is authenticated' do
      it 'allows admin to confirm bookings' do
        post "/api/v1/partners/#{partner.id}/bulk_bookings/confirm",
             params: valid_params,
             headers: admin_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success_count']).to eq(2)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        post "/api/v1/partners/#{partner.id}/bulk_bookings/confirm",
             params: valid_params

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/partners/:partner_id/bulk_bookings/cancel' do
    let(:cancellation_reason) { create(:cancellation_reason) }
    let(:valid_params) do
      {
        booking_ids: [pending_booking1.id, confirmed_booking.id],
        cancellation_reason_id: cancellation_reason.id,
        cancellation_comment: 'Technical issues'
      }
    end

    it 'cancels multiple bookings with reason' do
      post "/api/v1/partners/#{partner.id}/bulk_bookings/cancel",
           params: valid_params,
           headers: partner_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['action']).to eq('cancel')
      expect(json['success_count']).to eq(2)

      # Verify bookings are cancelled
      expect(pending_booking1.reload.status).to eq('cancelled_by_partner')
      expect(pending_booking1.cancellation_reason_id).to eq(cancellation_reason.id)
      expect(pending_booking1.cancellation_comment).to eq('Technical issues')
    end

    it 'cannot cancel already completed bookings' do
      params = { booking_ids: [completed_booking.id] }

      post "/api/v1/partners/#{partner.id}/bulk_bookings/cancel",
           params: params,
           headers: partner_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['failed_count']).to eq(1)
    end
  end

  describe 'POST /api/v1/partners/:partner_id/bulk_bookings/reschedule' do
    let(:new_date) { (Date.current + 7.days).to_s }
    let(:new_time) { '14:00' }

    it 'reschedules pending bookings to a new date' do
      params = {
        booking_ids: [pending_booking1.id, pending_booking2.id],
        new_date: new_date,
        new_time: new_time
      }

      post "/api/v1/partners/#{partner.id}/bulk_bookings/reschedule",
           params: params,
           headers: partner_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success_count']).to eq(2)

      expect(pending_booking1.reload.booking_date.to_s).to eq(new_date)
    end

    it 'keeps original time when keep_original_time is true' do
      original_time = pending_booking1.start_time
      params = {
        booking_ids: [pending_booking1.id],
        new_date: new_date,
        new_time: new_time,
        keep_original_time: true
      }

      post "/api/v1/partners/#{partner.id}/bulk_bookings/reschedule",
           params: params,
           headers: partner_headers

      expect(response).to have_http_status(:ok)
      expect(pending_booking1.reload.start_time.strftime('%H:%M')).to eq(original_time.strftime('%H:%M'))
    end

    it 'returns error when new_date is missing' do
      params = { booking_ids: [pending_booking1.id] }

      post "/api/v1/partners/#{partner.id}/bulk_bookings/reschedule",
           params: params,
           headers: partner_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'cannot reschedule to a past date' do
      params = {
        booking_ids: [pending_booking1.id],
        new_date: (Date.current - 1.day).to_s
      }

      post "/api/v1/partners/#{partner.id}/bulk_bookings/reschedule",
           params: params,
           headers: partner_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['failed_count']).to eq(1)
      expect(json['failed'].first['error']).to include('past date')
    end
  end

  describe 'POST /api/v1/partners/:partner_id/bulk_bookings/complete' do
    it 'completes in_progress bookings' do
      in_progress_booking = create(:booking, service_point: service_point, status: 'in_progress')
      params = { booking_ids: [in_progress_booking.id] }

      post "/api/v1/partners/#{partner.id}/bulk_bookings/complete",
           params: params,
           headers: partner_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success_count']).to eq(1)
      expect(in_progress_booking.reload.status).to eq('completed')
    end

    it 'cannot complete pending bookings directly' do
      params = { booking_ids: [pending_booking1.id] }

      post "/api/v1/partners/#{partner.id}/bulk_bookings/complete",
           params: params,
           headers: partner_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['failed_count']).to eq(1)
    end
  end

  describe 'POST /api/v1/partners/:partner_id/bulk_bookings/no_show' do
    it 'marks confirmed bookings as no-show' do
      params = { booking_ids: [confirmed_booking.id] }

      post "/api/v1/partners/#{partner.id}/bulk_bookings/no_show",
           params: params,
           headers: partner_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success_count']).to eq(1)
      expect(confirmed_booking.reload.status).to eq('no_show')
    end
  end

  describe 'GET /api/v1/partners/:partner_id/bulk_bookings/preview' do
    it 'returns preview of selected bookings' do
      get "/api/v1/partners/#{partner.id}/bulk_bookings/preview",
          params: { booking_ids: [pending_booking1.id, confirmed_booking.id] },
          headers: partner_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['count']).to eq(2)
      expect(json['bookings']).to be_an(Array)

      booking_data = json['bookings'].first
      expect(booking_data).to include('id', 'status', 'booking_date', 'can_confirm', 'can_cancel')
    end

    it 'shows transition capabilities for each booking' do
      get "/api/v1/partners/#{partner.id}/bulk_bookings/preview",
          params: { booking_ids: [pending_booking1.id, completed_booking.id] },
          headers: partner_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      pending_preview = json['bookings'].find { |b| b['id'] == pending_booking1.id }
      completed_preview = json['bookings'].find { |b| b['id'] == completed_booking.id }

      expect(pending_preview['can_confirm']).to be true
      expect(completed_preview['can_confirm']).to be false
    end
  end

  describe 'access control' do
    let(:other_partner) { create(:partner) }
    let(:other_partner_user) { create(:user, :partner, partner: other_partner) }
    let(:other_headers) { authenticate_user(other_partner_user) }

    it 'prevents access to other partner bookings' do
      params = { booking_ids: [pending_booking1.id] }

      post "/api/v1/partners/#{partner.id}/bulk_bookings/confirm",
           params: params,
           headers: other_headers

      expect(response).to have_http_status(:forbidden)
    end
  end
end
