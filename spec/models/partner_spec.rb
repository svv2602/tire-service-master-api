require 'rails_helper'

RSpec.describe Partner, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:managers).dependent(:destroy) }
    it { should have_many(:service_points).dependent(:destroy) }
    it { should have_many(:price_lists).dependent(:destroy) }
    it { should have_many(:promotions).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:company_name) }
    it { should validate_presence_of(:user_id) }
    
    describe 'uniqueness of user_id' do
      let(:role) { UserRole.find_by(name: 'partner') || create(:user_role, name: 'partner') }
      let(:user) { create(:user, role_id: role.id) }
      before { create(:partner, user: user) }
      
      it 'validates uniqueness of user_id' do
        new_partner = build(:partner, user: user)
        expect(new_partner).not_to be_valid
        expect(new_partner.errors[:user_id]).to include('has already been taken')
      end
    end
  end

  describe 'scopes' do
    let!(:active_user) { create(:user, is_active: true) }
    let!(:inactive_user) { create(:user, is_active: false) }
    let!(:active_partner) { create(:partner, user: active_user) }
    let!(:inactive_partner) { create(:partner, user: inactive_user) }

    describe '.with_active_user' do
      it 'returns only partners with active users' do
        expect(Partner.with_active_user).to include(active_partner)
        expect(Partner.with_active_user).not_to include(inactive_partner)
      end
    end
  end

  describe '#total_clients_served' do
    let(:partner) { create(:partner) }
    let!(:service_point1) { create(:service_point, partner: partner, total_clients_served: 100, name: "Service Point A #{SecureRandom.hex(4)}-#{Time.now.to_f}") }
    let!(:service_point2) { create(:service_point, partner: partner, total_clients_served: 200, name: "Service Point B #{SecureRandom.hex(4)}-#{Time.now.to_f}") }

    it 'calculates total clients served across all service points' do
      expect(partner.total_clients_served).to eq(300)
    end

    context 'when partner has no service points' do
      let(:empty_partner) { create(:partner) }

      it 'returns zero' do
        expect(empty_partner.total_clients_served).to eq(0)
      end
    end
  end

  describe '#average_rating' do
    let(:partner) { create(:partner) }
    let!(:service_point1) { create(:service_point, partner: partner, average_rating: 4.0, name: "Service Point #1 #{SecureRandom.hex(4)}-#{Time.now.to_f}") }
    let!(:service_point2) { create(:service_point, partner: partner, average_rating: 5.0, name: "Service Point #2 #{SecureRandom.hex(4)}-#{Time.now.to_f}") }

    it 'calculates average rating across all service points' do
      expect(partner.average_rating).to eq(4.5)
    end

    context 'when partner has no service points' do
      let(:empty_partner) { create(:partner) }

      it 'returns zero' do
        expect(empty_partner.average_rating).to eq(0)
      end
    end
  end
end
