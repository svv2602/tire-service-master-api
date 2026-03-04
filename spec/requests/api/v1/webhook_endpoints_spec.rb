require 'rails_helper'

RSpec.describe 'Webhook Endpoints API', type: :request do
  let(:partner) { create(:partner) }
  let(:partner_user) { partner.user }
  let(:partner_headers) { valid_headers(partner_user) }
  let(:admin_role) { UserRole.find_or_create_by!(name: 'admin', description: 'Admin role') }
  let(:admin_user) { create(:user, role_id: admin_role.id) }
  let(:admin_headers) { valid_headers(admin_user) }

  describe 'GET /api/v1/partners/:partner_id/webhook_endpoints' do
    let!(:endpoint1) { create(:webhook_endpoint, partner: partner) }
    let!(:endpoint2) { create(:webhook_endpoint, partner: partner) }

    it 'returns all webhook endpoints for the partner' do
      get "/api/v1/partners/#{partner.id}/webhook_endpoints", headers: partner_headers

      expect(response).to have_http_status(:ok)
      expect(json['webhook_endpoints'].length).to eq(2)
      expect(json['supported_events']).to eq(WebhookEndpoint::SUPPORTED_EVENTS)
    end

    it 'does not return other partner endpoints' do
      other_partner = create(:partner)
      create(:webhook_endpoint, partner: other_partner)

      get "/api/v1/partners/#{partner.id}/webhook_endpoints", headers: partner_headers

      expect(json['webhook_endpoints'].length).to eq(2)
    end

    it 'denies access to other partner data' do
      other_partner = create(:partner)

      get "/api/v1/partners/#{other_partner.id}/webhook_endpoints", headers: partner_headers

      expect(response).to have_http_status(:forbidden)
    end

    it 'allows admin to access any partner endpoints' do
      get "/api/v1/partners/#{partner.id}/webhook_endpoints", headers: admin_headers

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /api/v1/partners/:partner_id/webhook_endpoints' do
    let(:valid_params) do
      {
        url: 'https://example.com/webhooks',
        events: ['booking.created', 'booking.confirmed'],
        description: 'My webhook'
      }
    end

    it 'creates a new webhook endpoint' do
      post "/api/v1/partners/#{partner.id}/webhook_endpoints",
           params: valid_params.to_json,
           headers: partner_headers

      expect(response).to have_http_status(:created)
      expect(json['webhook_endpoint']['url']).to eq('https://example.com/webhooks')
      expect(json['webhook_endpoint']['events']).to match_array(['booking.created', 'booking.confirmed'])
      expect(json['secret']).to be_present # Full secret shown on creation
    end

    it 'auto-generates a secret' do
      post "/api/v1/partners/#{partner.id}/webhook_endpoints",
           params: valid_params.to_json,
           headers: partner_headers

      expect(json['secret'].length).to eq(64)
    end

    it 'rejects invalid URL' do
      invalid_params = valid_params.merge(url: 'not-a-url')

      post "/api/v1/partners/#{partner.id}/webhook_endpoints",
           params: invalid_params.to_json,
           headers: partner_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects unsupported events' do
      invalid_params = valid_params.merge(events: ['unsupported.event'])

      post "/api/v1/partners/#{partner.id}/webhook_endpoints",
           params: invalid_params.to_json,
           headers: partner_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /api/v1/partners/:partner_id/webhook_endpoints/:id' do
    let!(:endpoint) { create(:webhook_endpoint, partner: partner) }

    it 'updates the webhook endpoint' do
      patch "/api/v1/partners/#{partner.id}/webhook_endpoints/#{endpoint.id}",
            params: { url: 'https://new-url.com/hook', is_active: false }.to_json,
            headers: partner_headers

      expect(response).to have_http_status(:ok)
      expect(json['webhook_endpoint']['url']).to eq('https://new-url.com/hook')
      expect(json['webhook_endpoint']['is_active']).to be false
    end
  end

  describe 'DELETE /api/v1/partners/:partner_id/webhook_endpoints/:id' do
    let!(:endpoint) { create(:webhook_endpoint, partner: partner) }

    it 'deletes the webhook endpoint' do
      expect {
        delete "/api/v1/partners/#{partner.id}/webhook_endpoints/#{endpoint.id}",
               headers: partner_headers
      }.to change(WebhookEndpoint, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /api/v1/partners/:partner_id/webhook_endpoints/:id/test' do
    let!(:endpoint) { create(:webhook_endpoint, partner: partner) }

    it 'creates a test delivery and enqueues job' do
      expect {
        post "/api/v1/partners/#{partner.id}/webhook_endpoints/#{endpoint.id}/test",
             headers: partner_headers
      }.to change(WebhookDelivery, :count).by(1)
        .and have_enqueued_job(WebhookDeliveryJob)

      expect(response).to have_http_status(:ok)
      expect(json['delivery_id']).to be_present
    end
  end

  describe 'GET /api/v1/partners/:partner_id/webhook_endpoints/:id/deliveries' do
    let!(:endpoint) { create(:webhook_endpoint, partner: partner) }
    let!(:delivery1) { create(:webhook_delivery, :success, webhook_endpoint: endpoint) }
    let!(:delivery2) { create(:webhook_delivery, :failed, webhook_endpoint: endpoint) }

    it 'returns paginated deliveries' do
      get "/api/v1/partners/#{partner.id}/webhook_endpoints/#{endpoint.id}/deliveries",
          headers: partner_headers

      expect(response).to have_http_status(:ok)
      expect(json['deliveries'].length).to eq(2)
      expect(json['pagination']).to be_present
    end
  end
end
