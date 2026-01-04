require 'rails_helper'

RSpec.describe TireOrder, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:supplier) }
    it { should belong_to(:partner).optional }
    it { should have_many(:tire_order_items).dependent(:destroy) }
    it { should have_many(:supplier_tire_products).through(:tire_order_items) }
    it { should have_many(:partner_rewards).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:tire_order) }

    it { should validate_presence_of(:client_name) }
    it { should validate_presence_of(:client_phone) }
    it { should validate_length_of(:client_name).is_at_most(255) }
    it { should validate_length_of(:tracking_number).is_at_most(100) }
    it { should validate_numericality_of(:total_amount).is_greater_than_or_equal_to(0) }

    context 'phone format' do
      it 'accepts valid phone numbers' do
        valid_phones = ['+380501234567', '380501234567', '+38 (050) 123-45-67', '0501234567']
        valid_phones.each do |phone|
          order = build(:tire_order, client_phone: phone)
          expect(order).to be_valid, "Expected #{phone} to be valid"
        end
      end

      it 'rejects invalid phone numbers' do
        invalid_phones = ['abc', '123', '']
        invalid_phones.each do |phone|
          order = build(:tire_order, client_phone: phone)
          expect(order).not_to be_valid, "Expected #{phone} to be invalid"
        end
      end
    end
  end

  describe 'scopes' do
    let!(:draft_order) { create(:tire_order, status: 'draft') }
    let!(:submitted_order) { create(:tire_order, :submitted) }
    let!(:confirmed_order) { create(:tire_order, :confirmed) }
    let!(:shipped_order) { create(:tire_order, :shipped) }
    let!(:completed_order) { create(:tire_order, :completed) }
    let!(:cancelled_order) { create(:tire_order, :cancelled) }

    it '.pending returns submitted orders' do
      expect(TireOrder.pending).to include(submitted_order)
      expect(TireOrder.pending).not_to include(draft_order, confirmed_order)
    end

    it '.confirmed returns only confirmed orders' do
      expect(TireOrder.confirmed).to eq([confirmed_order])
    end

    it '.shipped returns only shipped orders' do
      expect(TireOrder.shipped).to eq([shipped_order])
    end

    it '.completed returns only completed orders' do
      expect(TireOrder.completed).to eq([completed_order])
    end

    it '.cancelled returns only cancelled orders' do
      expect(TireOrder.cancelled).to eq([cancelled_order])
    end

    it '.active returns non-final orders' do
      expect(TireOrder.active).to include(submitted_order, confirmed_order, shipped_order)
      expect(TireOrder.active).not_to include(completed_order, cancelled_order)
    end

    it '.final returns completed, cancelled, and archived orders' do
      expect(TireOrder.final).to include(completed_order, cancelled_order)
      expect(TireOrder.final).not_to include(submitted_order, confirmed_order)
    end
  end

  describe 'AASM state machine' do
    let(:order) { create(:tire_order, :with_items) }

    describe 'initial state' do
      it 'starts in draft state' do
        expect(order).to be_draft
      end
    end

    describe '#submit' do
      context 'from draft with items' do
        it 'transitions to submitted' do
          expect(order.submit).to be true
          expect(order).to be_submitted
        end
      end

      context 'from draft without items' do
        let(:empty_order) { create(:tire_order) }

        it 'does not transition without items' do
          expect(empty_order.submit).to be false
          expect(empty_order).to be_draft
        end
      end
    end

    describe '#confirm' do
      let(:submitted_order) { create(:tire_order, :submitted) }

      it 'transitions from submitted to confirmed' do
        expect(submitted_order.confirm).to be true
        expect(submitted_order).to be_confirmed
      end

      it 'does not transition from draft' do
        expect(order.confirm).to be false
        expect(order).to be_draft
      end
    end

    describe '#start_processing' do
      let(:confirmed_order) { create(:tire_order, :confirmed) }

      it 'transitions from confirmed to processing' do
        expect(confirmed_order.start_processing).to be true
        expect(confirmed_order).to be_processing
      end
    end

    describe '#ship' do
      let(:processing_order) { create(:tire_order, :processing) }

      it 'transitions from processing to shipped' do
        expect(processing_order.ship).to be true
        expect(processing_order).to be_shipped
        expect(processing_order.shipped_at).to be_present
      end
    end

    describe '#deliver' do
      let(:shipped_order) { create(:tire_order, :shipped) }

      it 'transitions from shipped to delivered' do
        expect(shipped_order.deliver).to be true
        expect(shipped_order).to be_delivered
        expect(shipped_order.delivered_at).to be_present
      end
    end

    describe '#complete' do
      let(:delivered_order) { create(:tire_order, :delivered) }

      it 'transitions from delivered to completed' do
        expect(delivered_order.complete).to be true
        expect(delivered_order).to be_completed
      end
    end

    describe '#cancel' do
      it 'can cancel from submitted' do
        submitted_order = create(:tire_order, :submitted)
        expect(submitted_order.cancel).to be true
        expect(submitted_order).to be_cancelled
      end

      it 'can cancel from confirmed' do
        confirmed_order = create(:tire_order, :confirmed)
        expect(confirmed_order.cancel).to be true
        expect(confirmed_order).to be_cancelled
      end

      it 'cannot cancel from completed' do
        completed_order = create(:tire_order, :completed)
        expect(completed_order.cancel).to be false
        expect(completed_order).to be_completed
      end
    end

    describe '#archive' do
      it 'can archive completed order' do
        completed_order = create(:tire_order, :completed)
        expect(completed_order.archive).to be true
        expect(completed_order).to be_archived
      end

      it 'can archive cancelled order' do
        cancelled_order = create(:tire_order, :cancelled)
        expect(cancelled_order.archive).to be true
        expect(cancelled_order).to be_archived
      end

      it 'cannot archive active order' do
        confirmed_order = create(:tire_order, :confirmed)
        expect(confirmed_order.archive).to be false
      end
    end

    describe '#available_events' do
      it 'returns available transitions for draft' do
        expect(order.available_events).to include(:submit)
      end

      it 'returns available transitions for submitted' do
        submitted_order = create(:tire_order, :submitted)
        expect(submitted_order.available_events).to include(:confirm, :cancel)
      end
    end
  end

  describe 'instance methods' do
    describe '#items_count' do
      let(:order) { create(:tire_order) }

      it 'returns 0 for empty order' do
        expect(order.items_count).to eq(0)
      end

      it 'returns sum of quantities' do
        create(:tire_order_item, tire_order: order, quantity: 4, supplier_tire_product: create(:supplier_tire_product, supplier: order.supplier))
        create(:tire_order_item, tire_order: order, quantity: 2, supplier_tire_product: create(:supplier_tire_product, supplier: order.supplier))
        expect(order.items_count).to eq(6)
      end
    end

    describe '#status_display' do
      it 'returns human-readable status' do
        order = build(:tire_order, status: 'confirmed')
        expect(order.status_display).to eq('Подтверждён')
      end
    end

    describe '#can_be_cancelled_by_user?' do
      it 'returns true for draft' do
        expect(build(:tire_order, status: 'draft').can_be_cancelled_by_user?).to be true
      end

      it 'returns true for submitted' do
        expect(build(:tire_order, status: 'submitted').can_be_cancelled_by_user?).to be true
      end

      it 'returns false for shipped' do
        expect(build(:tire_order, status: 'shipped').can_be_cancelled_by_user?).to be false
      end
    end

    describe '#can_be_cancelled_by_admin?' do
      it 'returns true for shipped' do
        expect(build(:tire_order, status: 'shipped').can_be_cancelled_by_admin?).to be true
      end

      it 'returns false for delivered' do
        expect(build(:tire_order, status: 'delivered').can_be_cancelled_by_admin?).to be false
      end
    end

    describe '#mark_as_shipped!' do
      let(:processing_order) { create(:tire_order, :processing) }

      it 'ships order with tracking number' do
        processing_order.mark_as_shipped!('TRACK123')
        expect(processing_order).to be_shipped
        expect(processing_order.tracking_number).to eq('TRACK123')
      end
    end

    describe '#delivery_days' do
      it 'calculates days between shipped and delivered' do
        order = build(:tire_order, shipped_at: 3.days.ago, delivered_at: Time.current)
        expect(order.delivery_days).to eq(3)
      end

      it 'returns nil if not yet delivered' do
        order = build(:tire_order, shipped_at: Time.current, delivered_at: nil)
        expect(order.delivery_days).to be_nil
      end
    end
  end

  describe 'callbacks' do
    describe 'calculate_total_amount' do
      let(:order) { create(:tire_order) }
      let(:product) { create(:supplier_tire_product, supplier: order.supplier, price_uah: 5000) }

      it 'updates total when items added' do
        create(:tire_order_item, tire_order: order, supplier_tire_product: product, quantity: 4, price_at_order: 5000)
        order.reload
        expect(order.total_amount).to eq(20000)
      end
    end
  end
end
