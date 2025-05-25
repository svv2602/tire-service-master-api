require 'rails_helper'

# Добавляем хелпер для проверки скоупов
module PunditPolicyHelper
  def permissions_for_scope(scope_name, &block)
    describe "scope #{scope_name}" do
      instance_eval(&block)
    end
  end
end

RSpec.describe ServicePointPolicy, type: :policy do
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
  
  let!(:admin) { create(:administrator, user: admin_user) }
  let!(:partner) { create(:partner, user: partner_user) }
  let!(:manager) { create(:manager, user: manager_user, partner: partner) }
  let!(:client) { create(:client, user: client_user) }

  let(:service_point) { create(:service_point, partner: partner) }

  before do
    create(:manager_service_point, manager: manager, service_point: service_point)
  end

  context 'being an admin' do
    let(:user) { admin_user }

    permissions :index?, :show?, :create?, :update?, :destroy?, :nearby? do
      it 'grants access' do
        expect(subject).to permit(user, service_point)
      end
    end

    permissions_for_scope :resolve do
      it 'includes all service points' do
        scope = described_class::Scope.new(user, ServicePoint).resolve
        expect(scope).to include(service_point)
      end
    end
  end

  context 'being a partner' do
    let(:user) { partner_user }

    permissions :index?, :show?, :create?, :nearby? do
      it 'grants access' do
        expect(subject).to permit(user, service_point)
      end
    end

    permissions :update?, :destroy? do
      it 'grants access to their own service points' do
        expect(subject).to permit(user, service_point)
      end

      it 'denies access to other partners service points' do
        other_partner = create(:partner, user: create(:user, role: partner_role))
        other_service_point = create(:service_point, partner: other_partner)
        
        expect(subject).not_to permit(user, other_service_point)
      end
    end

    permissions_for_scope :resolve do
      it 'includes their own service points' do
        scope = described_class::Scope.new(user, ServicePoint).resolve
        expect(scope).to include(service_point)
      end

      it 'excludes other partners service points' do
        other_partner = create(:partner, user: create(:user, role: partner_role))
        other_service_point = create(:service_point, partner: other_partner)
        
        scope = described_class::Scope.new(user, ServicePoint).resolve
        expect(scope).not_to include(other_service_point)
      end
    end
  end

  context 'being a manager' do
    let(:user) { manager_user }

    permissions :index?, :show?, :nearby? do
      it 'grants access' do
        expect(subject).to permit(user, service_point)
      end
    end

    permissions :create?, :destroy? do
      it 'denies access' do
        expect(subject).not_to permit(user, service_point)
      end
    end

    permissions :update? do
      it 'grants access to service points they manage' do
        # Make sure manager is associated with the service point
        expect(manager.service_points).to include(service_point)
        expect(subject).to permit(user, service_point)
      end

      it 'denies access to service points they do not manage' do
        unmanaged_service_point = create(:service_point, partner: partner)
        expect(subject).not_to permit(user, unmanaged_service_point)
      end
    end

    permissions_for_scope :resolve do
      it 'includes service points they manage' do
        # Make sure manager is associated with the service point before testing
        expect(manager.service_points).to include(service_point)
        
        scope = described_class::Scope.new(user, ServicePoint).resolve
        expect(scope).to include(service_point)
      end

      it 'excludes service points they do not manage' do
        unmanaged_service_point = create(:service_point, partner: partner)
        
        scope = described_class::Scope.new(user, ServicePoint).resolve
        expect(scope).not_to include(unmanaged_service_point)
      end
    end
  end

  context 'being a client' do
    let(:user) { client_user }

    permissions :index?, :show?, :nearby? do
      it 'grants access' do
        expect(subject).to permit(user, service_point)
      end
    end

    permissions :create?, :update?, :destroy? do
      it 'denies access' do
        expect(subject).not_to permit(user, service_point)
      end
    end

    permissions_for_scope :resolve do
      it 'includes only active service points' do
        active_status = create(:service_point_status, name: 'active')
        inactive_status = create(:service_point_status, name: 'inactive')
        
        active_point = create(:service_point, status: active_status)
        inactive_point = create(:service_point, status: inactive_status)
        
        scope = described_class::Scope.new(user, ServicePoint).resolve
        expect(scope).to include(active_point)
        expect(scope).not_to include(inactive_point)
      end
    end
  end

  context 'being a guest' do
    let(:user) { nil }

    permissions :index?, :show?, :nearby? do
      it 'grants access' do
        expect(subject).to permit(user, service_point)
      end
    end

    permissions :create?, :update?, :destroy? do
      it 'denies access' do
        expect(subject).not_to permit(user, service_point)
      end
    end

    permissions_for_scope :resolve do
      it 'includes only active service points' do
        active_status = create(:service_point_status, name: 'active')
        inactive_status = create(:service_point_status, name: 'inactive')
        
        active_point = create(:service_point, status: active_status)
        inactive_point = create(:service_point, status: inactive_status)
        
        scope = described_class::Scope.new(user, ServicePoint).resolve
        expect(scope).to include(active_point)
        expect(scope).not_to include(inactive_point)
      end
    end
  end
end
