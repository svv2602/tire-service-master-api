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
  let(:another_partner_user) { create(:user, role: partner_role) }
  let(:manager_user) { create(:user, role: manager_role) }
  let(:client_user) { create(:user, role: client_role) }
  let(:another_client_user) { create(:user, role: client_role) }
  
  let!(:admin) { create(:administrator, user: admin_user) }
  let!(:partner) { create(:partner, user: partner_user) }
  let!(:another_partner) { create(:partner, user: another_partner_user) }
  let!(:manager) { create(:manager, user: manager_user, partner: partner) }
  let!(:client) { create(:client, user: client_user) }
  let!(:another_client) { create(:client, user: another_client_user) }
  
  # Создаем сервисные точки
  let!(:partner_service_point) { create(:service_point, partner: partner) }
  let!(:another_partner_service_point) { create(:service_point, partner: another_partner) }
  
  # Создаем бронирования для связи клиентов с партнерами
  let!(:client_booking_at_partner_point) { 
    create(:booking, client: client, service_point: partner_service_point) 
  }
  let!(:another_client_booking_at_another_partner_point) { 
    create(:booking, client: another_client, service_point: another_partner_service_point) 
  }

  permissions_for_scope :index do
    it 'grants access to admin' do
      expect(subject).to permit(admin_user, Client)
    end

    it 'grants access to partner' do
      expect(subject).to permit(partner_user, Client)
    end

    it 'grants access to manager' do
      expect(subject).to permit(manager_user, Client)
    end

    it 'denies access to client' do
      expect(subject).not_to permit(client_user, Client)
    end
  end

  permissions_for_scope :show do
    it 'allows admin to view any client' do
      expect(subject).to permit(admin_user, client)
      expect(subject).to permit(admin_user, another_client)
    end

    it 'allows manager to view any client' do
      expect(subject).to permit(manager_user, client)
      expect(subject).to permit(manager_user, another_client)
    end

    it 'allows client to view themselves' do
      expect(subject).to permit(client_user, client)
    end

    it 'denies client to view other clients' do
      expect(subject).not_to permit(client_user, another_client)
    end

    it 'allows partner to view clients who booked at their service points' do
      expect(subject).to permit(partner_user, client)
    end

    it 'denies partner to view clients who never booked at their service points' do
      expect(subject).not_to permit(partner_user, another_client)
    end
  end

  permissions_for_scope :update do
    it 'allows admin to update any client' do
      expect(subject).to permit(admin_user, client)
    end

    it 'allows client to update themselves' do
      expect(subject).to permit(client_user, client)
    end

    it 'denies client to update other clients' do
      expect(subject).not_to permit(client_user, another_client)
    end

    it 'allows partner to update clients who booked at their service points' do
      expect(subject).to permit(partner_user, client)
    end

    it 'denies partner to update clients who never booked at their service points' do
      expect(subject).not_to permit(partner_user, another_client)
    end
  end

  permissions_for_scope :destroy do
    it 'allows admin to destroy any client' do
      expect(subject).to permit(admin_user, client)
    end

    it 'allows client to destroy themselves' do
      expect(subject).to permit(client_user, client)
    end

    it 'denies partner to destroy any client' do
      expect(subject).not_to permit(partner_user, client)
      expect(subject).not_to permit(partner_user, another_client)
    end
  end

  describe 'Scope' do
    it 'returns all clients for admin' do
      scope = described_class::Scope.new(admin_user, Client).resolve
      expect(scope).to include(client, another_client)
    end

    it 'returns all clients for manager' do
      scope = described_class::Scope.new(manager_user, Client).resolve
      expect(scope).to include(client, another_client)
    end

    it 'returns only own client for client user' do
      scope = described_class::Scope.new(client_user, Client).resolve
      expect(scope).to include(client)
      expect(scope).not_to include(another_client)
    end

    it 'returns only clients who booked at partner service points' do
      scope = described_class::Scope.new(partner_user, Client).resolve
      expect(scope).to include(client)
      expect(scope).not_to include(another_client)
    end

    it 'returns empty scope for unauthenticated user' do
      scope = described_class::Scope.new(nil, Client).resolve
      expect(scope).to be_empty
    end
  end
end
