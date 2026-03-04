# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TireOrderPolicy, type: :policy do
  subject { described_class }

  let(:admin_role) { UserRole.find_or_create_by!(name: 'admin') { |r| r.description = 'Admin role' } }
  let(:client_role) { UserRole.find_or_create_by!(name: 'client') { |r| r.description = 'Client role' } }
  let(:partner_role) { UserRole.find_or_create_by!(name: 'partner') { |r| r.description = 'Partner role' } }

  let(:admin_user) { create(:user, role: admin_role) }
  let!(:admin_record) { Administrator.create!(user: admin_user) }
  let(:client_user) { create(:user, role: client_role) }
  let!(:client) { create(:client, user: client_user) }
  let(:other_client_user) { create(:user, role: client_role) }
  let!(:other_client) { create(:client, user: other_client_user) }

  let(:supplier) { create(:supplier) }
  let(:product) { create(:supplier_tire_product, supplier: supplier) }
  let(:order) do
    order = create(:tire_order, user: client_user, supplier: supplier, status: 'submitted', skip_broadcasts: true)
    create(:tire_order_item, tire_order: order, supplier_tire_product: product)
    order.reload
  end

  # -- index? --
  permissions :index? do
    it 'grants access to any authenticated user' do
      expect(subject).to permit(client_user, TireOrder)
      expect(subject).to permit(admin_user, TireOrder)
    end
  end

  # -- index_all? --
  permissions :index_all? do
    it 'grants access to admin' do
      expect(subject).to permit(admin_user, TireOrder)
    end

    it 'denies access to regular client' do
      expect(subject).not_to permit(client_user, TireOrder)
    end
  end

  # -- show? --
  permissions :show? do
    it 'grants access to admin for any order' do
      expect(subject).to permit(admin_user, order)
    end

    it 'grants access to the order owner' do
      expect(subject).to permit(client_user, order)
    end

    it 'denies access to another user' do
      expect(subject).not_to permit(other_client_user, order)
    end
  end

  # -- create? --
  permissions :create? do
    it 'grants access to any authenticated user' do
      expect(subject).to permit(client_user, TireOrder)
      expect(subject).to permit(admin_user, TireOrder)
    end

    it 'denies access to nil user' do
      expect(subject).not_to permit(nil, TireOrder)
    end
  end

  # -- update? --
  permissions :update? do
    it 'denies access to everyone' do
      expect(subject).not_to permit(admin_user, order)
      expect(subject).not_to permit(client_user, order)
    end
  end

  # -- destroy? --
  permissions :destroy? do
    it 'denies access to everyone' do
      expect(subject).not_to permit(admin_user, order)
      expect(subject).not_to permit(client_user, order)
    end
  end

  # -- confirm? --
  permissions :confirm? do
    it 'grants access to admin for submitted order' do
      expect(subject).to permit(admin_user, order)
    end

    it 'denies access to admin for confirmed order' do
      order.update_column(:status, 'confirmed')
      expect(subject).not_to permit(admin_user, order)
    end

    it 'denies access to regular client' do
      expect(subject).not_to permit(client_user, order)
    end
  end

  # -- start_processing? --
  permissions :start_processing? do
    it 'grants access to admin for confirmed order' do
      order.update_column(:status, 'confirmed')
      expect(subject).to permit(admin_user, order)
    end

    it 'denies access for submitted order' do
      expect(subject).not_to permit(admin_user, order)
    end

    it 'denies access to regular client' do
      order.update_column(:status, 'confirmed')
      expect(subject).not_to permit(client_user, order)
    end
  end

  # -- complete? --
  permissions :complete? do
    it 'grants access to admin for processing order' do
      order.update_column(:status, 'processing')
      expect(subject).to permit(admin_user, order)
    end

    it 'denies access to admin for submitted order' do
      expect(subject).not_to permit(admin_user, order)
    end
  end

  # -- cancel? --
  permissions :cancel? do
    context 'admin cancellation' do
      it 'allows admin to cancel submitted order' do
        expect(subject).to permit(admin_user, order)
      end

      it 'allows admin to cancel shipped order' do
        order.update_column(:status, 'shipped')
        expect(subject).to permit(admin_user, order)
      end

      it 'denies admin cancellation of delivered order' do
        order.update_column(:status, 'delivered')
        expect(subject).not_to permit(admin_user, order)
      end
    end

    context 'user cancellation' do
      it 'allows owner to cancel submitted order' do
        expect(subject).to permit(client_user, order)
      end

      it 'allows owner to cancel confirmed order' do
        order.update_column(:status, 'confirmed')
        expect(subject).to permit(client_user, order)
      end

      it 'denies owner cancellation of shipped order' do
        order.update_column(:status, 'shipped')
        expect(subject).not_to permit(client_user, order)
      end

      it 'denies cancellation by another user' do
        expect(subject).not_to permit(other_client_user, order)
      end
    end
  end

  # -- archive? --
  permissions :archive? do
    it 'allows owner to archive completed order' do
      order.update_column(:status, 'completed')
      expect(subject).to permit(client_user, order)
    end

    it 'allows owner to archive cancelled order' do
      order.update_column(:status, 'cancelled')
      expect(subject).to permit(client_user, order)
    end

    it 'denies archiving submitted order' do
      expect(subject).not_to permit(client_user, order)
    end
  end

  # -- Scope --
  describe 'Scope' do
    let!(:user_order) { order }
    let!(:other_order) do
      o = create(:tire_order, user: other_client_user, supplier: supplier, status: 'submitted', skip_broadcasts: true)
      create(:tire_order_item, tire_order: o, supplier_tire_product: product)
      o.reload
    end

    context 'as admin' do
      it 'returns all orders' do
        scope = described_class::Scope.new(admin_user, TireOrder).resolve
        expect(scope).to include(user_order, other_order)
      end
    end

    context 'as regular user' do
      it 'returns only own orders' do
        scope = described_class::Scope.new(client_user, TireOrder).resolve
        expect(scope).to include(user_order)
        expect(scope).not_to include(other_order)
      end
    end
  end
end
