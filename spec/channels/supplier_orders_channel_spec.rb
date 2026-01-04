# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupplierOrdersChannel, type: :channel do
  # Create supplier user first, then associate supplier with user
  let(:supplier_user) { create(:user) }
  let(:supplier) { create(:supplier, user: supplier_user) }
  let(:client_user) { create(:client_user) }
  let(:tire_order) { create(:tire_order, supplier: supplier, skip_broadcasts: true) }

  before do
    # Ensure supplier is created before stubbing connection
    supplier
    stub_connection(current_user: supplier_user)
  end

  describe '#subscribed' do
    context 'with supplier user' do
      it 'subscribes to supplier orders stream' do
        subscribe

        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from("orders:supplier_#{supplier.id}")
      end
    end

    context 'with non-supplier user' do
      before do
        stub_connection(current_user: client_user)
      end

      it 'rejects subscription' do
        subscribe

        expect(subscription).to be_rejected
      end
    end
  end

  describe '#unsubscribed' do
    it 'unsubscribes without errors' do
      subscribe
      expect { subscription.unsubscribe_from_channel }.not_to raise_error
    end
  end

  describe '.broadcast_new_order' do
    it 'broadcasts to supplier channel' do
      expect do
        SupplierOrdersChannel.broadcast_new_order(tire_order)
      end.to have_broadcasted_to("orders:supplier_#{supplier.id}")
        .with(hash_including(type: 'order_created'))
    end

    it 'includes order details in broadcast' do
      expect do
        SupplierOrdersChannel.broadcast_new_order(tire_order)
      end.to have_broadcasted_to("orders:supplier_#{supplier.id}")
        .with(hash_including(
                order: hash_including(
                  id: tire_order.id,
                  status: tire_order.status,
                  client_name: tire_order.client_name
                )
              ))
    end
  end

  describe '.broadcast_status_change' do
    before do
      tire_order.update_column(:status, 'confirmed')
    end

    it 'broadcasts status change to supplier channel' do
      expect do
        SupplierOrdersChannel.broadcast_status_change(tire_order)
      end.to have_broadcasted_to("orders:supplier_#{supplier.id}")
        .with(hash_including(type: 'order_status_changed'))
    end
  end

  describe '.broadcast_cancellation' do
    before do
      tire_order.update_column(:status, 'cancelled')
    end

    it 'broadcasts cancellation to supplier channel' do
      expect do
        SupplierOrdersChannel.broadcast_cancellation(tire_order)
      end.to have_broadcasted_to("orders:supplier_#{supplier.id}")
        .with(hash_including(type: 'order_cancelled'))
    end
  end

  describe '.broadcast_update' do
    it 'broadcasts update to supplier channel' do
      expect do
        SupplierOrdersChannel.broadcast_update(tire_order)
      end.to have_broadcasted_to("orders:supplier_#{supplier.id}")
        .with(hash_including(type: 'order_updated'))
    end
  end

  describe 'TireOrder model integration' do
    context 'when order is created' do
      it 'can call broadcast_new_order method' do
        # Verify the private method exists and can be called
        expect(tire_order.private_methods).to include(:broadcast_new_order)
        expect { tire_order.send(:broadcast_new_order) }.not_to raise_error
      end
    end

    context 'when order status changes' do
      before do
        tire_order.skip_broadcasts = false
      end

      it 'broadcasts status change event' do
        allow(SupplierOrdersChannel).to receive(:broadcast_status_change)

        tire_order.update!(status: 'confirmed')

        expect(SupplierOrdersChannel).to have_received(:broadcast_status_change).with(tire_order)
      end

      it 'broadcasts cancellation event when cancelled' do
        allow(SupplierOrdersChannel).to receive(:broadcast_cancellation)

        tire_order.update!(status: 'cancelled')

        expect(SupplierOrdersChannel).to have_received(:broadcast_cancellation).with(tire_order)
      end
    end

    context 'when order is updated (non-status)' do
      before do
        tire_order.skip_broadcasts = false
      end

      it 'broadcasts update event' do
        allow(SupplierOrdersChannel).to receive(:broadcast_update)

        tire_order.update!(tracking_number: 'TRACK123')

        expect(SupplierOrdersChannel).to have_received(:broadcast_update).with(tire_order)
      end
    end
  end
end
