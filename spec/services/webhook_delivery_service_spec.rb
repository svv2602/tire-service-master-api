require 'rails_helper'

RSpec.describe WebhookDeliveryService do
  let(:partner) { create(:partner) }
  let!(:endpoint) { create(:webhook_endpoint, partner: partner, events: ['booking.created'], is_active: true) }
  let(:payload) { { event: 'booking.created', data: { booking_id: 1, status: 'pending' } } }

  describe '.call' do
    it 'creates a delivery record and enqueues a job' do
      expect {
        WebhookDeliveryService.call(event: 'booking.created', payload: payload, partner: partner)
      }.to change(WebhookDelivery, :count).by(1)
        .and have_enqueued_job(WebhookDeliveryJob)
    end

    it 'does not create delivery for non-matching events' do
      expect {
        WebhookDeliveryService.call(event: 'review.created', payload: payload, partner: partner)
      }.not_to change(WebhookDelivery, :count)
    end

    it 'does not create delivery for inactive endpoints' do
      endpoint.update!(is_active: false)

      expect {
        WebhookDeliveryService.call(event: 'booking.created', payload: payload, partner: partner)
      }.not_to change(WebhookDelivery, :count)
    end

    it 'delivers to all matching endpoints' do
      create(:webhook_endpoint, partner: partner, events: ['booking.created'], is_active: true)

      expect {
        WebhookDeliveryService.call(event: 'booking.created', payload: payload, partner: partner)
      }.to change(WebhookDelivery, :count).by(2)
    end
  end

  describe '.deliver' do
    let(:delivery) { create(:webhook_delivery, webhook_endpoint: endpoint, event: 'booking.created', payload: payload) }

    context 'when request succeeds' do
      let(:mock_response) { instance_double(Net::HTTPResponse, code: '200', body: 'OK') }

      before do
        allow(WebhookDeliveryService).to receive(:send_request).and_return(mock_response)
      end

      it 'marks delivery as success' do
        WebhookDeliveryService.deliver(delivery.id)
        delivery.reload

        expect(delivery.status).to eq('success')
        expect(delivery.response_code).to eq(200)
        expect(delivery.delivered_at).to be_present
      end
    end

    context 'when request fails with server error' do
      let(:mock_response) { instance_double(Net::HTTPResponse, code: '500', body: 'Internal Server Error') }

      before do
        allow(WebhookDeliveryService).to receive(:send_request).and_return(mock_response)
        # Speed up tests by removing sleep between retries
        allow_any_instance_of(Object).to receive(:sleep)
      end

      it 'retries and then marks as failed' do
        WebhookDeliveryService.deliver(delivery.id)
        delivery.reload

        expect(delivery.status).to eq('failed')
        expect(delivery.attempt).to eq(3)
        expect(delivery.error_message).to include('HTTP 500')
      end
    end

    context 'when request raises network error' do
      before do
        allow(WebhookDeliveryService).to receive(:send_request).and_raise(Errno::ECONNREFUSED)
        allow_any_instance_of(Object).to receive(:sleep)
      end

      it 'retries and then marks as failed' do
        WebhookDeliveryService.deliver(delivery.id)
        delivery.reload

        expect(delivery.status).to eq('failed')
        expect(delivery.attempt).to eq(3)
        expect(delivery.error_message).to include('Errno::ECONNREFUSED')
      end
    end

    context 'when endpoint is inactive' do
      before do
        endpoint.update!(is_active: false)
      end

      it 'does not attempt delivery' do
        expect(WebhookDeliveryService).not_to receive(:send_request)
        WebhookDeliveryService.deliver(delivery.id)
        delivery.reload

        expect(delivery.status).to eq('pending')
      end
    end

    context 'when first attempt fails but second succeeds' do
      let(:fail_response) { instance_double(Net::HTTPResponse, code: '500', body: 'Error') }
      let(:success_response) { instance_double(Net::HTTPResponse, code: '200', body: 'OK') }

      before do
        allow(WebhookDeliveryService).to receive(:send_request)
          .and_return(fail_response, success_response)
        allow_any_instance_of(Object).to receive(:sleep)
      end

      it 'marks as success after retry' do
        WebhookDeliveryService.deliver(delivery.id)
        delivery.reload

        expect(delivery.status).to eq('success')
        expect(delivery.attempt).to eq(2)
      end
    end
  end

  describe '.compute_signature' do
    it 'generates valid HMAC-SHA256 hex digest' do
      secret = 'test_secret'
      body = '{"test":"data"}'
      expected = OpenSSL::HMAC.hexdigest('SHA256', secret, body)

      result = WebhookDeliveryService.compute_signature(secret, body)
      expect(result).to eq(expected)
    end
  end
end
