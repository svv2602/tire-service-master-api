require 'rails_helper'

RSpec.describe LoyaltyTransaction, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:loyalty_account) }
    it { is_expected.to belong_to(:booking).optional }
    it { is_expected.to belong_to(:tire_order).optional }
    it { is_expected.to belong_to(:review).optional }
    it { is_expected.to belong_to(:referral_user).optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:reason) }
    it { is_expected.to validate_inclusion_of(:reason).in_array(LoyaltyTransaction::REASONS) }

    it 'does not allow zero points' do
      transaction = build(:loyalty_transaction, points: 0)
      expect(transaction).not_to be_valid
    end
  end

  describe 'scopes' do
    let(:account) { create(:loyalty_account) }

    before do
      create(:loyalty_transaction, loyalty_account: account, points: 10)
      create(:loyalty_transaction, loyalty_account: account, points: 5, reason: 'review_submitted')
      create(:loyalty_transaction, loyalty_account: account, points: -5, reason: 'points_redeemed')
    end

    it '.credits returns only positive point transactions' do
      expect(LoyaltyTransaction.credits.count).to eq(2)
    end

    it '.debits returns only negative point transactions' do
      expect(LoyaltyTransaction.debits.count).to eq(1)
    end

    it '.by_reason filters by reason' do
      expect(LoyaltyTransaction.by_reason('review_submitted').count).to eq(1)
    end

    it '.recent orders by created_at desc' do
      transactions = LoyaltyTransaction.recent
      expect(transactions.first.created_at).to be >= transactions.last.created_at
    end
  end

  describe '.points_for_tire_order' do
    it 'calculates 1 point per 100 UAH' do
      expect(LoyaltyTransaction.points_for_tire_order(1500)).to eq(15)
    end

    it 'rounds down partial amounts' do
      expect(LoyaltyTransaction.points_for_tire_order(1099)).to eq(10)
    end

    it 'returns 0 for amounts under 100' do
      expect(LoyaltyTransaction.points_for_tire_order(99)).to eq(0)
    end
  end
end
