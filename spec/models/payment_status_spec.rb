require 'rails_helper'

RSpec.describe PaymentStatus, type: :model do
  describe 'associations' do
    it { should have_many(:bookings).with_foreign_key('payment_status_id').dependent(:restrict_with_error) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
  end

  describe 'scopes' do
    let!(:active_status) { create(:payment_status, is_active: true, sort_order: 2) }
    let!(:inactive_status) { create(:payment_status, is_active: false, sort_order: 3) }
    let!(:first_status) { create(:payment_status, is_active: true, sort_order: 1) }

    describe '.active' do
      it 'возвращает только активные статусы оплаты' do
        expect(PaymentStatus.active).to include(active_status, first_status)
        expect(PaymentStatus.active).not_to include(inactive_status)
      end
    end

    describe '.sorted' do
      it 'возвращает статусы, отсортированные по полю sort_order' do
        sorted_statuses = PaymentStatus.sorted.to_a
        
        expect(sorted_statuses.index(first_status)).to be < sorted_statuses.index(active_status)
        expect(sorted_statuses.index(active_status)).to be < sorted_statuses.index(inactive_status)
      end
    end
  end

  describe 'предопределенные статусы' do
    before do
      create(:payment_status, name: 'pending')
      create(:payment_status, name: 'paid')
      create(:payment_status, name: 'failed')
      create(:payment_status, name: 'refunded')
      create(:payment_status, name: 'partially_refunded')
    end

    describe '.pending_id' do
      it 'возвращает id статуса "pending"' do
        pending_status = PaymentStatus.find_by(name: 'pending')
        expect(PaymentStatus.pending_id).to eq(pending_status.id)
      end
    end

    describe '.paid_id' do
      it 'возвращает id статуса "paid"' do
        paid_status = PaymentStatus.find_by(name: 'paid')
        expect(PaymentStatus.paid_id).to eq(paid_status.id)
      end
    end

    describe '.failed_id' do
      it 'возвращает id статуса "failed"' do
        failed_status = PaymentStatus.find_by(name: 'failed')
        expect(PaymentStatus.failed_id).to eq(failed_status.id)
      end
    end

    describe '.refunded_id' do
      it 'возвращает id статуса "refunded"' do
        refunded_status = PaymentStatus.find_by(name: 'refunded')
        expect(PaymentStatus.refunded_id).to eq(refunded_status.id)
      end
    end

    describe '.partially_refunded_id' do
      it 'возвращает id статуса "partially_refunded"' do
        partially_refunded_status = PaymentStatus.find_by(name: 'partially_refunded')
        expect(PaymentStatus.partially_refunded_id).to eq(partially_refunded_status.id)
      end
    end
  end
end
