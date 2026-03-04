# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Payments API', type: :request do
  let(:client_user) { create(:user) }
  let(:admin_user) { create(:admin) }
  let(:client) { create(:client, user: client_user) }
  let(:service_point) { create(:service_point) }
  let(:booking) { create(:booking, client: client, service_point: service_point, total_price: 500.0) }

  describe 'POST /api/v1/payments/booking/:booking_id' do
    let(:headers) { auth_headers(client_user) }

    before do
      allow_any_instance_of(LiqpayService).to receive(:create_booking_payment).and_return({
        checkout_url: 'https://www.liqpay.ua/api/3/checkout',
        data: 'encoded_data',
        signature: 'test_signature',
        order_id: "booking_#{booking.id}_12345",
        amount: 500.0,
        sandbox: true
      })
    end

    it 'creates a payment and returns LiqPay data' do
      post "/api/v1/payments/booking/#{booking.id}", headers: headers

      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body[:success]).to be true
      expect(body[:payment][:checkout_url]).to be_present
      expect(body[:payment][:data]).to eq('encoded_data')
      expect(body[:payment][:signature]).to eq('test_signature')
    end

    it 'returns 404 for non-existent booking' do
      post '/api/v1/payments/booking/999999', headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 403 for unauthorized user' do
      other_user = create(:user)
      post "/api/v1/payments/booking/#{booking.id}", headers: auth_headers(other_user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /api/v1/payments/liqpay/callback' do
    let(:private_key) { 'test_private_key' }
    let(:liqpay_data) do
      {
        status: 'success',
        order_id: "booking_#{booking.id}_12345",
        payment_id: 'lp_pay_123',
        amount: 500.0,
        currency: 'UAH',
        description: 'Test payment',
        transaction_id: 'txn_456',
        info: { booking_id: booking.id, payment_type: 'booking' }.to_json
      }
    end
    let(:encoded_data) { Base64.strict_encode64(liqpay_data.to_json) }
    let(:signature) do
      sign_string = private_key + encoded_data + private_key
      Base64.strict_encode64(Digest::SHA1.digest(sign_string))
    end

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('LIQPAY_PUBLIC_KEY').and_return('test_public_key')
      allow(ENV).to receive(:[]).with('LIQPAY_PRIVATE_KEY').and_return(private_key)
      allow(ENV).to receive(:[]).with('LIQPAY_SANDBOX').and_return('true')
    end

    it 'processes a successful callback' do
      post '/api/v1/payments/liqpay/callback', params: { data: encoded_data, signature: signature }

      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body[:success]).to be true
      expect(body[:status]).to eq('success')
    end

    it 'rejects callback with invalid signature' do
      post '/api/v1/payments/liqpay/callback', params: { data: encoded_data, signature: 'invalid' }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 400 when data or signature is missing' do
      post '/api/v1/payments/liqpay/callback', params: { data: encoded_data }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'GET /api/v1/payments/status/:order_id' do
    let(:headers) { auth_headers(client_user) }

    before do
      allow_any_instance_of(LiqpayService).to receive(:check_payment_status).and_return({
        'status' => 'success',
        'amount' => 500.0,
        'currency' => 'UAH',
        'description' => 'Test payment'
      })
    end

    it 'returns payment status' do
      get '/api/v1/payments/status/booking_1_12345', headers: headers

      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body[:success]).to be true
      expect(body[:status]).to eq('success')
      expect(body[:amount]).to eq(500.0)
    end
  end

  describe 'POST /api/v1/payments/refund' do
    let(:payment) { create(:payment, :success, payment_type: 'booking', entity_id: booking.id, user: client_user) }

    context 'as admin' do
      let(:headers) { auth_headers(admin_user) }

      before do
        allow_any_instance_of(LiqpayService).to receive(:refund_payment).and_return({
          'status' => 'reversed'
        })
      end

      it 'processes a refund' do
        post '/api/v1/payments/refund',
             params: { order_id: payment.payment_id, amount: payment.amount },
             headers: headers

        expect(response).to have_http_status(:ok)
        body = json_response
        expect(body[:success]).to be true

        payment.reload
        expect(payment.status).to eq('refunded')
        expect(payment.refunded_at).to be_present
      end

      it 'rejects refund with invalid params' do
        post '/api/v1/payments/refund',
             params: { order_id: '', amount: 0 },
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'as client' do
      let(:headers) { auth_headers(client_user) }

      it 'returns 403 for non-admin' do
        post '/api/v1/payments/refund',
             params: { order_id: payment.payment_id, amount: payment.amount },
             headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
