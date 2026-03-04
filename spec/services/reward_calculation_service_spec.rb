# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RewardCalculationService, type: :service do
  let(:partner_role) { UserRole.find_or_create_by!(name: 'partner') { |r| r.description = 'Partner role' } }
  let(:partner_user) { create(:user, role: partner_role) }
  let(:partner) { create(:partner, user: partner_user, is_active: true) }
  let(:supplier) { create(:supplier, is_active: true) }
  let(:product) { create(:supplier_tire_product, supplier: supplier) }

  # Create a submitted order for testing
  let(:tire_order) do
    order = create(:tire_order, user: partner_user, supplier: supplier, status: 'submitted', skip_broadcasts: true)
    create(:tire_order_item, tire_order: order, supplier_tire_product: product, quantity: 4, price_at_order: 5000.0)
    order.reload
  end

  describe '#calculate_and_create_reward' do
    context 'with nil order' do
      it 'returns false and adds error' do
        service = described_class.new(nil)
        result = service.calculate_and_create_reward

        expect(result).to be_falsey
        expect(service.errors).to include('Заказ не найден')
      end
    end

    context 'with invalid order status' do
      it 'returns false for draft orders' do
        draft_order = create(:tire_order, user: partner_user, supplier: supplier, status: 'draft', skip_broadcasts: true)
        service = described_class.new(draft_order)
        result = service.calculate_and_create_reward

        expect(result).to be_falsey
        expect(service.errors).to include('Заказ должен быть отправлен, подтвержден или выполнен')
      end

      it 'returns false for cancelled orders' do
        cancelled_order = create(:tire_order, user: partner_user, supplier: supplier, status: 'cancelled', skip_broadcasts: true)
        service = described_class.new(cancelled_order)
        result = service.calculate_and_create_reward

        expect(result).to be_falsey
      end
    end

    context 'when partner is not found' do
      let(:client_role) { UserRole.find_or_create_by!(name: 'client') { |r| r.description = 'Client role' } }
      let(:client_user) { create(:user, role: client_role) }

      it 'returns false when user is a regular client' do
        order = create(:tire_order, user: client_user, supplier: supplier, status: 'submitted', skip_broadcasts: true)
        create(:tire_order_item, tire_order: order, supplier_tire_product: product)
        service = described_class.new(order.reload)
        result = service.calculate_and_create_reward

        expect(result).to be_falsey
        expect(service.errors).to include('Не удалось определить партнера для заказа')
      end
    end

    context 'when inactive partner' do
      before { partner.update!(is_active: false) }

      it 'returns false' do
        service = described_class.new(tire_order)
        result = service.calculate_and_create_reward

        expect(result).to be_falsey
        expect(service.errors).to include('Партнер неактивен')
      end
    end

    context 'when inactive supplier' do
      before do
        partner # ensure Partner record exists
        supplier.update!(is_active: false)
      end

      it 'returns false' do
        service = described_class.new(tire_order)
        result = service.calculate_and_create_reward

        expect(result).to be_falsey
        expect(service.errors).to include('Поставщик неактивен')
      end
    end

    context 'when no active agreement exists' do
      before { partner } # ensure Partner record exists

      it 'returns false' do
        service = described_class.new(tire_order)
        result = service.calculate_and_create_reward

        expect(result).to be_falsey
        expect(service.errors).to include('Нет активных договоренностей между партнером и поставщиком')
      end
    end
  end

  describe '#preview_reward' do
    context 'with nil order' do
      it 'returns nil' do
        service = described_class.new(nil)
        expect(service.preview_reward).to be_nil
      end
    end

    context 'with invalid order status' do
      it 'returns nil for draft orders' do
        draft_order = create(:tire_order, user: partner_user, supplier: supplier, status: 'draft', skip_broadcasts: true)
        service = described_class.new(draft_order)
        expect(service.preview_reward).to be_nil
      end
    end
  end

  describe '#reward_exists?' do
    context 'when no reward exists' do
      it 'returns false' do
        service = described_class.new(tire_order)
        expect(service.reward_exists?).to be false
      end
    end
  end

  describe 'valid_order? checks' do
    it 'accepts submitted TireOrder' do
      service = described_class.new(tire_order)
      expect(service.send(:valid_order?)).to be true
    end

    it 'accepts confirmed TireOrder' do
      tire_order.update_column(:status, 'confirmed')
      service = described_class.new(tire_order)
      expect(service.send(:valid_order?)).to be true
    end

    it 'accepts completed TireOrder' do
      tire_order.update_column(:status, 'completed')
      service = described_class.new(tire_order)
      expect(service.send(:valid_order?)).to be true
    end

    it 'rejects draft TireOrder' do
      tire_order.update_column(:status, 'draft')
      service = described_class.new(tire_order)
      expect(service.send(:valid_order?)).to be false
    end
  end
end
