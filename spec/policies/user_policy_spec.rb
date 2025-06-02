require 'rails_helper'

RSpec.describe UserPolicy, type: :policy do
  subject { described_class }

  let(:admin_role) { UserRole.find_or_create_by(name: 'admin') { |role| role.description = 'Administrator role' } }
  let(:manager_role) { UserRole.find_or_create_by(name: 'manager') { |role| role.description = 'Manager role' } }
  let(:partner_role) { UserRole.find_or_create_by(name: 'partner') { |role| role.description = 'Partner role' } }
  let(:client_role) { UserRole.find_or_create_by(name: 'client') { |role| role.description = 'Client role' } }

  let(:admin_user) { create(:user, role: admin_role) }
  let(:manager_user) { create(:user, role: manager_role) }
  let(:partner_user) { create(:user, role: partner_role) }
  let(:client_user) { create(:user, role: client_role) }
  let(:other_user) { create(:user, role: client_role) }

  permissions :index? do
    it 'grants access to admin' do
      expect(subject).to permit(admin_user, User)
    end

    it 'denies access to manager' do
      expect(subject).not_to permit(manager_user, User)
    end

    it 'denies access to partner' do
      expect(subject).not_to permit(partner_user, User)
    end

    it 'denies access to client' do
      expect(subject).not_to permit(client_user, User)
    end
  end

  permissions :show? do
    it 'grants access to admin for any user' do
      expect(subject).to permit(admin_user, other_user)
    end

    it 'grants access to user for their own record' do
      expect(subject).to permit(client_user, client_user)
      expect(subject).to permit(partner_user, partner_user)
      expect(subject).to permit(manager_user, manager_user)
    end

    it 'denies access to user for other user records' do
      expect(subject).not_to permit(client_user, other_user)
      expect(subject).not_to permit(partner_user, other_user)
      expect(subject).not_to permit(manager_user, other_user)
    end
  end

  permissions :create? do
    it 'grants access to admin' do
      expect(subject).to permit(admin_user, User)
    end

    it 'denies access to non-admin users' do
      expect(subject).not_to permit(manager_user, User)
      expect(subject).not_to permit(partner_user, User)
      expect(subject).not_to permit(client_user, User)
    end
  end

  permissions :update? do
    it 'grants access to admin for any user' do
      expect(subject).to permit(admin_user, other_user)
    end

    it 'grants access to user for their own record' do
      expect(subject).to permit(client_user, client_user)
      expect(subject).to permit(partner_user, partner_user)
      expect(subject).to permit(manager_user, manager_user)
    end

    it 'denies access to user for other user records' do
      expect(subject).not_to permit(client_user, other_user)
      expect(subject).not_to permit(partner_user, other_user)
      expect(subject).not_to permit(manager_user, other_user)
    end
  end

  permissions :destroy? do
    it 'grants access to admin for other users' do
      expect(subject).to permit(admin_user, other_user)
      expect(subject).to permit(admin_user, partner_user)
      expect(subject).to permit(admin_user, manager_user)
    end

    it 'denies access to admin for their own record' do
      expect(subject).not_to permit(admin_user, admin_user)
    end

    it 'denies access to non-admin users' do
      expect(subject).not_to permit(manager_user, other_user)
      expect(subject).not_to permit(partner_user, other_user)
      expect(subject).not_to permit(client_user, other_user)
      expect(subject).not_to permit(client_user, client_user)
    end
  end

  permissions :manage? do
    it 'grants access to admin' do
      expect(subject).to permit(admin_user, User)
    end

    it 'denies access to non-admin users' do
      expect(subject).not_to permit(manager_user, User)
      expect(subject).not_to permit(partner_user, User)
      expect(subject).not_to permit(client_user, User)
    end
  end

  describe 'Scope' do
    let!(:users) { [admin_user, manager_user, partner_user, client_user, other_user] }
    
    context 'when user is admin' do
      it 'returns all users' do
        scope = Pundit.policy_scope(admin_user, User)
        expect(scope.count).to eq(User.count)
        expect(scope).to include(*users)
      end
    end

    context 'when user is not admin' do
      it 'returns only the current user for client' do
        scope = Pundit.policy_scope(client_user, User)
        expect(scope.count).to eq(1)
        expect(scope).to include(client_user)
        expect(scope).not_to include(other_user, admin_user, manager_user, partner_user)
      end

      it 'returns only the current user for partner' do
        scope = Pundit.policy_scope(partner_user, User)
        expect(scope.count).to eq(1)
        expect(scope).to include(partner_user)
        expect(scope).not_to include(other_user, admin_user, manager_user, client_user)
      end

      it 'returns only the current user for manager' do
        scope = Pundit.policy_scope(manager_user, User)
        expect(scope.count).to eq(1)
        expect(scope).to include(manager_user)
        expect(scope).not_to include(other_user, admin_user, partner_user, client_user)
      end
    end
  end
end 