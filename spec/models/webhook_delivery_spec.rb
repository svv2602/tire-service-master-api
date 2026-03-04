require 'rails_helper'

RSpec.describe WebhookDelivery, type: :model do
  describe 'associations' do
    it { should belong_to(:webhook_endpoint) }
  end

  describe 'validations' do
    subject { build(:webhook_delivery) }

    it { should validate_presence_of(:event) }
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:status).in_array(WebhookDelivery::STATUSES) }
  end

  describe 'scopes' do
    let!(:pending_delivery) { create(:webhook_delivery, status: 'pending') }
    let!(:success_delivery) { create(:webhook_delivery, :success) }
    let!(:failed_delivery) { create(:webhook_delivery, :failed) }

    describe '.successful' do
      it 'returns only successful deliveries' do
        expect(WebhookDelivery.successful).to include(success_delivery)
        expect(WebhookDelivery.successful).not_to include(pending_delivery, failed_delivery)
      end
    end

    describe '.failed' do
      it 'returns only failed deliveries' do
        expect(WebhookDelivery.failed).to include(failed_delivery)
        expect(WebhookDelivery.failed).not_to include(pending_delivery, success_delivery)
      end
    end

    describe '.recent' do
      it 'orders by created_at desc' do
        deliveries = WebhookDelivery.recent
        expect(deliveries.first).to eq(failed_delivery)
      end
    end
  end

  describe '#mark_success!' do
    let(:delivery) { create(:webhook_delivery) }

    it 'updates status and response fields' do
      delivery.mark_success!(response_code: 200, response_body: 'OK')
      delivery.reload

      expect(delivery.status).to eq('success')
      expect(delivery.response_code).to eq(200)
      expect(delivery.response_body).to eq('OK')
      expect(delivery.delivered_at).to be_present
    end
  end

  describe '#mark_failed!' do
    let(:delivery) { create(:webhook_delivery) }

    it 'updates status and error fields' do
      delivery.mark_failed!(
        response_code: 500,
        response_body: 'Internal Server Error',
        error_message: 'Server returned 500'
      )
      delivery.reload

      expect(delivery.status).to eq('failed')
      expect(delivery.response_code).to eq(500)
      expect(delivery.error_message).to eq('Server returned 500')
    end

    it 'truncates long response bodies' do
      long_body = 'x' * 10_000
      delivery.mark_failed!(response_body: long_body)
      delivery.reload

      expect(delivery.response_body.length).to be <= 5000
    end
  end
end
