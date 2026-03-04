# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminMetricsChannel, type: :channel do
  let(:admin_role) { UserRole.find_or_create_by(name: 'admin') { |role| role.description = 'Administrator' } }
  let(:client_role) { UserRole.find_or_create_by(name: 'client') { |role| role.description = 'Client' } }
  let(:admin_user) { create(:user, role: admin_role) }
  let(:client_user) { create(:user, role: client_role) }

  context 'when admin subscribes' do
    before do
      stub_connection current_user: admin_user
    end

    it 'subscribes successfully' do
      subscribe
      expect(subscription).to be_confirmed
    end

    it 'streams from admin_metrics' do
      subscribe
      expect(subscription).to have_stream_from('admin_metrics')
    end
  end

  context 'when non-admin subscribes' do
    before do
      stub_connection current_user: client_user
    end

    it 'rejects the subscription' do
      subscribe
      expect(subscription).to be_rejected
    end
  end

  describe '.broadcast_new_booking' do
    let(:service_point) { create(:service_point) }
    let(:booking) { create(:booking, service_point: service_point, skip_notifications: true) }

    it 'broadcasts to admin_metrics stream' do
      expect {
        described_class.broadcast_new_booking(booking)
      }.to have_broadcasted_to('admin_metrics')
        .with(hash_including(event: 'new_booking'))
    end
  end

  describe '.broadcast_new_order' do
    let(:order) { create(:tire_order, skip_broadcasts: true) }

    it 'broadcasts to admin_metrics stream' do
      expect {
        described_class.broadcast_new_order(order)
      }.to have_broadcasted_to('admin_metrics')
        .with(hash_including(event: 'new_order'))
    end
  end

  describe '.broadcast_new_user' do
    it 'broadcasts to admin_metrics stream' do
      expect {
        described_class.broadcast_new_user(admin_user)
      }.to have_broadcasted_to('admin_metrics')
        .with(hash_including(event: 'new_user'))
    end
  end
end
