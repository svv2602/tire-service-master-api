# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Payment History API', type: :request do
  let(:client_user) { create(:user) }
  let(:admin_user) { create(:admin) }
  let(:headers) { auth_headers(client_user) }

  let!(:payment_booking) do
    create(:payment, :success, payment_type: 'booking', entity_id: 1, user: client_user, amount: 500.0)
  end
  let!(:payment_order) do
    create(:payment, :success, payment_type: 'order', entity_id: 2, user: client_user, amount: 1200.0)
  end

  describe 'GET /api/v1/payments' do
    it 'returns paginated payment history' do
      get '/api/v1/payments', headers: headers

      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body[:data].length).to eq(2)
      expect(body[:meta][:totalCount]).to eq(2)
    end

    it 'filters by type' do
      get '/api/v1/payments', params: { type: 'booking' }, headers: headers

      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body[:data].length).to eq(1)
      expect(body[:data][0][:type]).to eq('booking')
    end

    it 'filters by status' do
      create(:payment, :failed, user: client_user)

      get '/api/v1/payments', params: { status: 'success' }, headers: headers

      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body[:data].length).to eq(2)
    end

    it 'only shows own payments for non-admin' do
      other_user = create(:user)
      create(:payment, :success, user: other_user)

      get '/api/v1/payments', headers: headers

      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body[:data].length).to eq(2) # Only client_user's payments
    end

    it 'shows all payments for admin' do
      create(:payment, :success, user: create(:user))

      get '/api/v1/payments', headers: auth_headers(admin_user)

      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body[:data].length).to eq(3)
    end
  end

  describe 'GET /api/v1/payments/:id' do
    it 'returns payment detail' do
      get "/api/v1/payments/#{payment_booking.id}", headers: headers

      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body[:id]).to eq(payment_booking.id)
      expect(body[:amount]).to eq(500.0)
      expect(body[:providerPaymentId]).to be_present
    end

    it 'returns 404 for other user payment' do
      other_user = create(:user)
      other_payment = create(:payment, :success, user: other_user)

      get "/api/v1/payments/#{other_payment.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/payments/:payment_id/refund_request' do
    it 'creates a refund request for a successful payment' do
      post "/api/v1/payments/#{payment_booking.id}/refund_request",
           params: {
             amount: 500.0,
             reason: 'Service not provided',
             reason_category: 'notDelivered',
             is_full_refund: true
           },
           headers: headers

      expect(response).to have_http_status(:created)
      body = json_response
      expect(body[:success]).to be true
      expect(body[:refundId]).to be_present
    end

    it 'rejects refund for pending payment' do
      pending_payment = create(:payment, user: client_user, status: 'pending')

      post "/api/v1/payments/#{pending_payment.id}/refund_request",
           params: {
             amount: 100.0,
             reason: 'Test reason',
             reason_category: 'other',
             is_full_refund: false
           },
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
