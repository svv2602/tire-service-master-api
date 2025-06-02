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
    it { should validate_presence_of(:contact_person) }
    it { should validate_presence_of(:legal_address) }
    it { should validate_presence_of(:user_id) }
    
    it 'validates uniqueness of tax_number when present' do
      # Этот тест проверяет, что налоговый номер должен быть уникальным, если указан
      # Но может быть пустым (nil или '')
      expect(Partner.validators_on(:tax_number).map(&:class)).to include(ActiveRecord::Validations::UniquenessValidator)
    end
  end

  describe 'scopes' do
    describe '.with_active_user' do
      it 'returns only partners with active users' do
        role = UserRole.find_or_create_by(name: 'partner') { |r| r.description = 'Partner role' }
        
        active_user = create(:user, is_active: true, role_id: role.id)
        inactive_user = create(:user, is_active: false, role_id: role.id)
        
        active_partner = create(:partner, user: active_user)
        inactive_partner = create(:partner, user: inactive_user)

        expect(Partner.with_active_user).to include(active_partner)
        expect(Partner.with_active_user).not_to include(inactive_partner)
      end
    end
  end

  describe '#total_clients_served' do
    it 'calculates total clients served across all service points' do
      role = UserRole.find_or_create_by(name: 'partner') { |r| r.description = 'Partner role' }
      partner_user = create(:user, role_id: role.id)
      partner = create(:partner, user: partner_user)
      service_point1 = create(:service_point, partner: partner, total_clients_served: 100, name: "Service Point A #{SecureRandom.hex(4)}-#{Time.now.to_f}")
      service_point2 = create(:service_point, partner: partner, total_clients_served: 200, name: "Service Point B #{SecureRandom.hex(4)}-#{Time.now.to_f}")
      
      expect(partner.total_clients_served).to eq(300)
    end

    it 'returns zero when partner has no service points' do
      role = UserRole.find_or_create_by(name: 'partner') { |r| r.description = 'Partner role' }
      empty_partner_user = create(:user, role_id: role.id)
      empty_partner = create(:partner, user: empty_partner_user)

      expect(empty_partner.total_clients_served).to eq(0)
    end
  end

  describe '#average_rating' do
    it 'calculates average rating across all service points' do
      role = UserRole.find_or_create_by(name: 'partner') { |r| r.description = 'Partner role' }
      partner_user = create(:user, role_id: role.id)
      partner = create(:partner, user: partner_user)
      service_point1 = create(:service_point, partner: partner, average_rating: 4.0, name: "Service Point #1 #{SecureRandom.hex(4)}-#{Time.now.to_f}")
      service_point2 = create(:service_point, partner: partner, average_rating: 5.0, name: "Service Point #2 #{SecureRandom.hex(4)}-#{Time.now.to_f}")

      expect(partner.average_rating).to eq(4.5)
    end

    it 'returns zero when partner has no service points' do
      role = UserRole.find_or_create_by(name: 'partner') { |r| r.description = 'Partner role' }
      empty_partner_user = create(:user, role_id: role.id)
      empty_partner = create(:partner, user: empty_partner_user)

      expect(empty_partner.average_rating).to eq(0)
    end
  end
end
