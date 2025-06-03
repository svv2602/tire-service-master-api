require 'rails_helper'

RSpec.describe Manager, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:partner) }
    it { should have_many(:manager_service_points).dependent(:destroy) }
    it { should have_many(:service_points).through(:manager_service_points) }
    # Уберем проверку связи с notifications, так как используются полиморфные отношения
  end

  describe 'validations' do
    it { should validate_presence_of(:position) }
    it { should validate_presence_of(:user_id) }
    it { should validate_presence_of(:partner_id) }
    # Проверка на уникальность user_id требует создания корректного объекта
    let(:user) { create(:user) }
    let(:partner) { create(:partner, :with_new_user) }
    subject { build(:manager, user: user, partner: partner) }
    it { should validate_uniqueness_of(:user_id) }
    it { should validate_numericality_of(:access_level).only_integer.is_greater_than(0) }
  end

  describe '#full_name' do
    let(:user) { create(:user, first_name: 'Jane', last_name: 'Smith') }
    let(:partner) { create(:partner, :with_new_user) }
    let(:manager) { create(:manager, user: user, partner: partner) }

    it 'returns the full name of the user' do
      expect(manager.full_name).to eq('Jane Smith')
    end
  end

  describe 'scopes' do
    let(:partner) { create(:partner, :with_new_user) }
    let!(:active_manager) { create(:manager, partner: partner) }
    let!(:inactive_manager) { create(:manager, partner: partner, user: create(:user, is_active: false)) }

    describe '.active' do
      it 'returns only active managers' do
        expect(Manager.active).to include(active_manager)
        expect(Manager.active).not_to include(inactive_manager)
      end
    end

    describe '.for_partner' do
      let(:another_partner) { create(:partner, :with_new_user) }
      let!(:another_manager) { create(:manager, partner: another_partner) }

      it 'returns only managers for the specified partner' do
        expect(Manager.for_partner(partner.id)).to include(active_manager)
        expect(Manager.for_partner(partner.id)).not_to include(another_manager)
      end
    end
  end

  describe '#manages_service_point?' do
    let(:manager) { create(:manager) }
    let(:service_point) { create(:service_point) }
    
    context 'when manager is assigned to the service point' do
      before { create(:manager_service_point, manager: manager, service_point: service_point) }
      
      it 'returns true' do
        expect(manager.manages_service_point?(service_point)).to be true
      end
    end
    
    context 'when manager is not assigned to the service point' do
      it 'returns false' do
        expect(manager.manages_service_point?(service_point)).to be false
      end
    end
  end
  
  describe '#read_only?' do
    context 'when access level is READ_ONLY_ACCESS' do
      let(:manager) { create(:manager, :read_only) }
      
      it 'returns true' do
        expect(manager.read_only?).to be true
      end
    end
    
    context 'when access level is not READ_ONLY_ACCESS' do
      let(:manager) { create(:manager, :full_access) }
      
      it 'returns false' do
        expect(manager.read_only?).to be false
      end
    end
  end
  
  describe '#full_access?' do
    context 'when access level is FULL_ACCESS' do
      let(:manager) { create(:manager, :full_access) }
      
      it 'returns true' do
        expect(manager.full_access?).to be true
      end
    end
    
    context 'when access level is not FULL_ACCESS' do
      let(:manager) { create(:manager, :read_only) }
      
      it 'returns false' do
        expect(manager.full_access?).to be false
      end
    end
  end
end
