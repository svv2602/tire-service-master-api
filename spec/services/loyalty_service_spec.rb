require 'rails_helper'

RSpec.describe LoyaltyService do
  describe '.find_or_create_account' do
    let(:user) { create(:client_user) }

    it 'creates a new account if none exists' do
      expect {
        LoyaltyService.find_or_create_account(user)
      }.to change(LoyaltyAccount, :count).by(1)
    end

    it 'returns existing account if present' do
      existing = create(:loyalty_account, user: user)

      result = LoyaltyService.find_or_create_account(user)
      expect(result.id).to eq(existing.id)
    end
  end

  describe '.award_booking_completed' do
    let(:client) { create(:client) }
    let(:booking) { create(:booking, :completed, client: client) }

    it 'awards 10 points for a completed booking' do
      expect {
        LoyaltyService.award_booking_completed(booking)
      }.to change {
        LoyaltyService.find_or_create_account(client.user).points
      }.by(10)
    end

    it 'creates a transaction with booking reference' do
      LoyaltyService.award_booking_completed(booking)

      transaction = LoyaltyTransaction.last
      expect(transaction.reason).to eq('booking_completed')
      expect(transaction.booking_id).to eq(booking.id)
      expect(transaction.points).to eq(10)
    end

    it 'does nothing when booking has no client' do
      booking_without_client = create(:booking, client: nil)

      expect {
        LoyaltyService.award_booking_completed(booking_without_client)
      }.not_to change(LoyaltyTransaction, :count)
    end
  end

  describe '.award_review_submitted' do
    let(:client) { create(:client) }
    let(:service_point) { create(:service_point) }
    let(:review) do
      Review.create!(
        client: client,
        service_point: service_point,
        rating: 5,
        comment: 'Great service!',
        status: 'published',
        is_published: true
      )
    end

    it 'awards 5 points for a review' do
      expect {
        LoyaltyService.award_review_submitted(review)
      }.to change {
        LoyaltyService.find_or_create_account(client.user).points
      }.by(5)
    end

    it 'creates a transaction with review reference' do
      LoyaltyService.award_review_submitted(review)

      transaction = LoyaltyTransaction.last
      expect(transaction.reason).to eq('review_submitted')
      expect(transaction.review_id).to eq(review.id)
    end
  end

  describe '.award_referral' do
    let(:user) { create(:client_user) }
    let(:referred_user) { create(:client_user) }

    it 'awards 50 points for a referral' do
      expect {
        LoyaltyService.award_referral(user, referred_user)
      }.to change {
        LoyaltyService.find_or_create_account(user).points
      }.by(50)
    end

    it 'creates a transaction with referral user reference' do
      LoyaltyService.award_referral(user, referred_user)

      transaction = LoyaltyTransaction.last
      expect(transaction.reason).to eq('referral')
      expect(transaction.referral_user_id).to eq(referred_user.id)
    end
  end

  describe '.award_tire_order' do
    let(:user) { create(:client_user) }
    let(:supplier) { create(:supplier) }
    let(:tire_order) do
      order = create(:tire_order, user: user, supplier: supplier)
      # Bypass calculate_total_amount callback which resets from items
      order.update_column(:total_amount, 1500)
      order.reload
    end

    it 'awards 1 point per 100 UAH' do
      expect {
        LoyaltyService.award_tire_order(tire_order)
      }.to change {
        LoyaltyService.find_or_create_account(user).points
      }.by(15)
    end

    it 'does not award points for amounts under 100 UAH' do
      small_order = create(:tire_order, user: user, supplier: supplier)
      small_order.update_column(:total_amount, 50)
      small_order.reload

      expect {
        LoyaltyService.award_tire_order(small_order)
      }.not_to change(LoyaltyTransaction, :count)
    end
  end

  describe '.balance' do
    let(:user) { create(:client_user) }

    it 'returns balance info hash' do
      create(:loyalty_account, user: user, points: 150, level: 'silver')

      result = LoyaltyService.balance(user)

      expect(result[:points]).to eq(150)
      expect(result[:level]).to eq('silver')
      expect(result[:next_level]).to eq('gold')
      expect(result[:points_to_next_level]).to eq(350)
    end
  end

  describe 'level upgrades through point accumulation' do
    let(:user) { create(:client_user) }
    let(:client) { user.client }

    it 'upgrades from bronze to silver after accumulating 100 points' do
      account = LoyaltyService.find_or_create_account(user)
      expect(account.level).to eq('bronze')

      # Simulate 10 completed bookings (10 points each = 100 total)
      10.times do
        booking = create(:booking, :completed, client: client)
        LoyaltyService.award_booking_completed(booking)
      end

      account.reload
      expect(account.points).to eq(100)
      expect(account.level).to eq('silver')
    end
  end
end
