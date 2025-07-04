require 'rails_helper'

RSpec.describe Operator, type: :model do
  before(:each) do
    # Создаем роль оператора, если она не существует
    UserRole.find_or_create_by(name: 'operator', description: 'Оператор сервисной точки', is_active: true)
  end

  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:position) }
    it { should validate_presence_of(:access_level) }
    it { should validate_inclusion_of(:access_level).in_range(1..5) }
    it { should validate_inclusion_of(:is_active).in_array([true, false]) }
  end

  describe 'scopes' do
    let(:user_role) { UserRole.find_by(name: 'operator') }
    let(:user1) { create(:user, role: user_role) }
    let(:user2) { create(:user, role: user_role) }
    let(:user3) { create(:user, role: user_role) }
    
    let!(:active_operator) { create(:operator, user: user1, is_active: true) }
    let!(:inactive_operator) { create(:operator, user: user2, is_active: false) }
    let!(:level1_operator) { create(:operator, user: user3, access_level: 1) }

    it 'returns active operators' do
      expect(Operator.active).to include(active_operator)
      expect(Operator.active).not_to include(inactive_operator)
    end

    it 'returns inactive operators' do
      expect(Operator.inactive).to include(inactive_operator)
      expect(Operator.inactive).not_to include(active_operator)
    end

    it 'returns operators by access level' do
      expect(Operator.by_access_level(1)).to include(level1_operator)
      expect(Operator.by_access_level(1)).not_to include(active_operator) unless active_operator.access_level == 1
    end
  end

  describe 'instance methods' do
    let(:user_role) { UserRole.find_by(name: 'operator') }
    let(:user) { create(:user, role: user_role) }
    let(:operator) { create(:operator, user: user, is_active: false, access_level: 3) }

    describe '#activate!' do
      it 'activates the operator' do
        operator.activate!
        expect(operator.reload.is_active).to eq(true)
      end
    end

    describe '#deactivate!' do
      it 'deactivates the operator' do
        operator.update(is_active: true)
        operator.deactivate!
        expect(operator.reload.is_active).to eq(false)
      end
    end

    describe '#can_access?' do
      it 'returns true when operator has sufficient access level' do
        expect(operator.can_access?(2)).to eq(true)
      end

      it 'returns false when operator has insufficient access level' do
        expect(operator.can_access?(4)).to eq(false)
      end
    end
  end
end
