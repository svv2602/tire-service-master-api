require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_one(:client).dependent(:destroy) }
    it { should have_one(:manager).dependent(:destroy) }
    it { should have_one(:administrator).dependent(:destroy) }
    it { should have_many(:system_logs).dependent(:nullify) }
  end

  describe 'validations' do
    it { should validate_presence_of(:email) }
    
    describe 'email uniqueness' do
      subject { create(:user, phone: nil) }
      it { should validate_uniqueness_of(:email).case_insensitive }
    end
    
    it { should validate_presence_of(:role_id) }
  end

  describe '#client?' do
    let(:client_role) { create(:user_role, name: 'client') }
    
    it 'returns true when user role is client' do
      user = create(:user, role: client_role)
      expect(user.client?).to be true
    end
    
    it 'returns false when user role is not client' do
      admin_role = create(:user_role, name: 'administrator')
      user = create(:user, role: admin_role)
      expect(user.client?).to be false
    end
  end

  describe '#manager?' do
    let(:manager_role) { create(:user_role, name: 'manager') }
    
    it 'returns true when user role is manager' do
      user = create(:user, role: manager_role)
      expect(user.manager?).to be true
    end
    
    it 'returns false when user role is not manager' do
      admin_role = create(:user_role, name: 'administrator')
      user = create(:user, role: admin_role)
      expect(user.manager?).to be false
    end
  end

  describe '#admin?' do
    let(:admin_role) { create(:user_role, name: 'admin') }
    
    it 'returns true when user role is admin' do
      user = create(:user, role: admin_role)
      expect(user.admin?).to be true
    end
    
    it 'returns false when user role is not admin' do
      client_role = create(:user_role, name: 'client')
      user = create(:user, role: client_role)
      expect(user.admin?).to be false
    end
  end
end
