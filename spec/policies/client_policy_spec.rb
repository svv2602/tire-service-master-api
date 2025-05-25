require 'rails_helper'

# Добавляем хелпер для проверки скоупов
module PunditPolicyHelper
  def permissions_for_scope(scope_name, &block)
    describe "scope #{scope_name}" do
      instance_eval(&block)
    end
  end
end

RSpec.describe ClientPolicy, type: :policy do
  extend PunditPolicyHelper
  
  subject { described_class }

  let(:admin_role) { UserRole.find_or_create_by(name: 'admin') { |role| role.description = 'Administrator role with full access' } }
  let(:partner_role) { UserRole.find_or_create_by(name: 'partner') { |role| role.description = 'Partner role for business owners' } }
  let(:manager_role) { UserRole.find_or_create_by(name: 'manager') { |role| role.description = 'Manager role for service point managers' } }
  let(:client_role) { UserRole.find_or_create_by(name: 'client') { |role| role.description = 'Client role for users who book services' } }
  
  let(:admin_user) { create(:user, role: admin_role) }
  let(:partner_user) { create(:user, role: partner_role) }
  let(:manager_user) { create(:user, role: manager_role) }
  let(:client_user) { create(:user, role: client_role) }
  let(:another_client_user) { create(:user, role: client_role) }
  
  let!(:admin) { create(:administrator, user: admin_user) }
  let!(:partner) { create(:partner, user: partner_user) }
  let!(:manager) { create(:manager, user: manager_user, partner: partner) }
  let!(:client) { create(:client, user: client_user) }
  let!(:another_client) { create(:client, user: another_client_user) }

  context 'being an admin' do
    let(:user) { admin_user }

    permissions :index?, :show?, :create?, :update?, :destroy? do
      it 'grants access' do
        expect(subject).to permit(user, client)
      end
    end

    permissions_for_scope :resolve do
      it 'includes all clients' do
        scope = described_class::Scope.new(user, Client).resolve
        expect(scope).to include(client, another_client)
      end
    end
  end

  context 'being a partner' do
    let(:user) { partner_user }

    permissions :index?, :show? do
      it 'grants access' do
        expect(subject).to permit(user, client)
      end
    end

    permissions :create?, :update?, :destroy? do
      it 'denies access' do
        expect(subject).not_to permit(user, client)
      end
    end
  end

  context 'being a manager' do
    let(:user) { manager_user }

    permissions :index?, :show? do
      it 'grants access' do
        expect(subject).to permit(user, client)
      end
    end

    permissions :create?, :update?, :destroy? do
      it 'denies access' do
        expect(subject).not_to permit(user, client)
      end
    end
  end

  context 'being the same client' do
    let(:user) { client_user }

    permissions :show?, :update? do
      it 'grants access to own profile' do
        expect(subject).to permit(user, client)
      end
    end

    permissions :index?, :create? do
      it 'denies access' do
        expect(subject).not_to permit(user, client)
      end
    end

    permissions :destroy? do
      it 'grants access to destroy own profile' do
        expect(subject).to permit(user, client)
      end
    end

    permissions :show?, :update? do
      it 'denies access to other client profiles' do
        expect(subject).not_to permit(user, another_client)
      end
    end

    permissions_for_scope :resolve do
      it 'includes only own client' do
        scope = described_class::Scope.new(user, Client).resolve
        expect(scope).to include(client)
        expect(scope).not_to include(another_client)
      end
    end
  end

  context 'being another client' do
    let(:user) { another_client_user }

    permissions :show?, :update?, :destroy? do
      it 'denies access to other client profiles' do
        expect(subject).not_to permit(user, client)
      end
    end
  end
end
