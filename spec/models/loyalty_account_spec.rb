require 'rails_helper'

RSpec.describe LoyaltyAccount, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:loyalty_transactions).dependent(:destroy) }
  end

  describe 'validations' do
    subject { create(:loyalty_account) }

    it { is_expected.to validate_numericality_of(:points).only_integer }
    it { is_expected.to validate_presence_of(:level) }
    it { is_expected.to validate_inclusion_of(:level).in_array(LoyaltyAccount::LEVEL_NAMES) }
    it { is_expected.to validate_uniqueness_of(:user_id) }
  end

  describe '#calculated_level' do
    let(:account) { build(:loyalty_account) }

    it 'returns bronze for 0-99 points' do
      account.points = 0
      expect(account.calculated_level).to eq('bronze')

      account.points = 99
      expect(account.calculated_level).to eq('bronze')
    end

    it 'returns silver for 100-499 points' do
      account.points = 100
      expect(account.calculated_level).to eq('silver')

      account.points = 499
      expect(account.calculated_level).to eq('silver')
    end

    it 'returns gold for 500+ points' do
      account.points = 500
      expect(account.calculated_level).to eq('gold')

      account.points = 1000
      expect(account.calculated_level).to eq('gold')
    end
  end

  describe 'level auto-recalculation' do
    let(:account) { create(:loyalty_account, points: 50, level: 'bronze') }

    it 'upgrades to silver when points reach 100' do
      account.update!(points: 100)
      expect(account.level).to eq('silver')
    end

    it 'upgrades to gold when points reach 500' do
      account.update!(points: 500)
      expect(account.level).to eq('gold')
    end

    it 'downgrades to bronze when points drop below 100' do
      account.update!(points: 150)
      expect(account.level).to eq('silver')

      account.update!(points: 50)
      expect(account.level).to eq('bronze')
    end
  end

  describe '#credit_points!' do
    let(:account) { create(:loyalty_account, points: 0) }

    it 'adds points and creates a transaction' do
      expect {
        account.credit_points!(10, reason: 'booking_completed', description: 'Test')
      }.to change { account.points }.by(10)
        .and change { account.loyalty_transactions.count }.by(1)
    end

    it 'does not add zero or negative points' do
      expect {
        account.credit_points!(0, reason: 'booking_completed')
      }.not_to change { account.points }

      expect {
        account.credit_points!(-5, reason: 'booking_completed')
      }.not_to change { account.points }
    end
  end

  describe '#debit_points!' do
    let(:account) { create(:loyalty_account, points: 50) }

    it 'deducts points and creates a negative transaction' do
      expect {
        account.debit_points!(20, reason: 'points_redeemed', description: 'Redeemed')
      }.to change { account.points }.by(-20)

      expect(account.loyalty_transactions.last.points).to eq(-20)
    end

    it 'raises error when insufficient points' do
      expect {
        account.debit_points!(100, reason: 'points_redeemed')
      }.to raise_error(LoyaltyAccount::InsufficientPointsError)
    end
  end

  describe '#level_progress' do
    it 'returns percentage for bronze level' do
      account = build(:loyalty_account, points: 50, level: 'bronze')
      expect(account.level_progress).to eq(50)
    end

    it 'returns percentage for silver level' do
      account = build(:loyalty_account, points: 300, level: 'silver')
      expect(account.level_progress).to eq(50)
    end

    it 'returns 100 for gold level' do
      account = build(:loyalty_account, points: 600, level: 'gold')
      expect(account.level_progress).to eq(100)
    end
  end

  describe '#points_to_next_level' do
    it 'calculates points needed for bronze to silver' do
      account = build(:loyalty_account, points: 60, level: 'bronze')
      expect(account.points_to_next_level).to eq(40)
    end

    it 'calculates points needed for silver to gold' do
      account = build(:loyalty_account, points: 300, level: 'silver')
      expect(account.points_to_next_level).to eq(200)
    end

    it 'returns 0 for gold level' do
      account = build(:loyalty_account, points: 600, level: 'gold')
      expect(account.points_to_next_level).to eq(0)
    end
  end

  describe '#next_level' do
    it 'returns silver for bronze' do
      expect(build(:loyalty_account, level: 'bronze').next_level).to eq('silver')
    end

    it 'returns gold for silver' do
      expect(build(:loyalty_account, level: 'silver').next_level).to eq('gold')
    end

    it 'returns nil for gold' do
      expect(build(:loyalty_account, level: 'gold').next_level).to be_nil
    end
  end
end
