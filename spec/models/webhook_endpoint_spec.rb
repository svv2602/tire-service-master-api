require 'rails_helper'

RSpec.describe WebhookEndpoint, type: :model do
  describe 'associations' do
    it { should belong_to(:partner) }
    it { should have_many(:webhook_deliveries).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:webhook_endpoint) }

    it { should validate_presence_of(:url) }
    # Note: secret is auto-generated on create, so we test it differently
    it 'validates secret presence when set to blank after creation' do
      endpoint = create(:webhook_endpoint)
      endpoint.secret = ''
      expect(endpoint).not_to be_valid
    end
    it { should validate_presence_of(:events) }

    it 'validates URL format' do
      endpoint = build(:webhook_endpoint, url: 'not-a-url')
      expect(endpoint).not_to be_valid
      expect(endpoint.errors[:url]).to include('must be a valid HTTP(S) URL')
    end

    it 'accepts valid HTTPS URL' do
      endpoint = build(:webhook_endpoint, url: 'https://example.com/webhook')
      expect(endpoint).to be_valid
    end

    it 'accepts valid HTTP URL' do
      endpoint = build(:webhook_endpoint, url: 'http://example.com/webhook')
      expect(endpoint).to be_valid
    end

    it 'rejects unsupported events' do
      endpoint = build(:webhook_endpoint, events: ['unsupported.event'])
      expect(endpoint).not_to be_valid
      expect(endpoint.errors[:events].first).to include('unsupported events')
    end

    it 'accepts supported events' do
      endpoint = build(:webhook_endpoint, events: ['booking.created', 'review.created'])
      expect(endpoint).to be_valid
    end
  end

  describe 'scopes' do
    let!(:active_endpoint) { create(:webhook_endpoint, is_active: true, events: ['booking.created']) }
    let!(:inactive_endpoint) { create(:webhook_endpoint, :inactive, events: ['booking.created']) }

    describe '.active' do
      it 'returns only active endpoints' do
        expect(WebhookEndpoint.active).to include(active_endpoint)
        expect(WebhookEndpoint.active).not_to include(inactive_endpoint)
      end
    end

    describe '.for_event' do
      it 'returns active endpoints subscribed to the given event' do
        expect(WebhookEndpoint.for_event('booking.created')).to include(active_endpoint)
        expect(WebhookEndpoint.for_event('booking.created')).not_to include(inactive_endpoint)
      end

      it 'does not return endpoints not subscribed to the event' do
        expect(WebhookEndpoint.for_event('review.created')).not_to include(active_endpoint)
      end
    end
  end

  describe 'callbacks' do
    it 'generates secret automatically on create when not provided' do
      endpoint = create(:webhook_endpoint, secret: nil)
      expect(endpoint.secret).to be_present
      expect(endpoint.secret.length).to eq(64)
    end
  end

  describe '#regenerate_secret!' do
    it 'generates a new secret' do
      endpoint = create(:webhook_endpoint)
      old_secret = endpoint.secret
      endpoint.regenerate_secret!
      expect(endpoint.secret).not_to eq(old_secret)
      expect(endpoint.secret.length).to eq(64)
    end
  end

  describe 'SUPPORTED_EVENTS' do
    it 'includes all expected events' do
      expected = %w[
        booking.created
        booking.confirmed
        booking.completed
        order.status_changed
        review.created
      ]
      expect(WebhookEndpoint::SUPPORTED_EVENTS).to match_array(expected)
    end
  end
end
