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
    let(:client_role) { UserRole.find_or_create_by(name: 'client') { |role| role.description = 'Client role for users who book services' } }
    
    it 'returns true when user role is client' do
      user = create(:user, role: client_role)
      expect(user.client?).to be true
    end
    
    it 'returns false when user role is not client' do
      admin_role = UserRole.find_or_create_by(name: 'administrator') { |role| role.description = 'Administrator role' }
      user = create(:user, role: admin_role)
      expect(user.client?).to be false
    end
  end

  describe '#manager?' do
    let(:manager_role) { UserRole.find_or_create_by(name: 'manager') { |role| role.description = 'Manager role for service point managers' } }
    
    it 'returns true when user role is manager' do
      user = create(:user, role: manager_role)
      expect(user.manager?).to be true
    end
    
    it 'returns false when user role is not manager' do
      admin_role = UserRole.find_or_create_by(name: 'administrator') { |role| role.description = 'Administrator role' }
      user = create(:user, role: admin_role)
      expect(user.manager?).to be false
    end
  end

  describe '#admin?' do
    let(:admin_role) { UserRole.find_or_create_by(name: 'admin') { |role| role.description = 'Administrator role with full access' } }
    
    it 'returns true when user role is admin' do
      user = create(:user, role: admin_role)
      expect(user.admin?).to be true
    end
    
    it 'returns false when user role is not admin' do
      client_role = UserRole.find_or_create_by(name: 'client') { |role| role.description = 'Client role for users who book services' }
      user = create(:user, role: client_role)
      expect(user.admin?).to be false
    end
  end
end
