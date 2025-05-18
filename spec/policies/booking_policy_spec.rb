require 'rails_helper'

# Добавляем хелпер для проверки скоупов
module PunditPolicyHelper
  def permissions_for_scope(scope_name, &block)
    describe "scope #{scope_name}" do
      instance_eval(&block)
    end
  end
end

RSpec.describe BookingPolicy, type: :policy do
  include BookingTestHelper
  include PunditPolicyHelper

  subject { described_class }

  let(:admin_role) { create(:user_role, name: 'administrator') }
  let(:partner_role) { create(:user_role, name: 'partner') }
  let(:manager_role) { create(:user_role, name: 'manager') }
  let(:client_role) { create(:user_role, name: 'client') }
  
  # Create users with proper roles
  let(:admin_user) { create(:user, role: admin_role) }
  let(:partner_user) { create(:user, role: partner_role) }
  let(:manager_user) { create(:user, role: manager_role) }
  let(:client_user) { create(:user, role: client_role) }
  
  # Create associated records
  let!(:admin) { create(:administrator, user: admin_user) }
  let!(:partner) { create(:partner, user: partner_user) }
  let!(:manager) { create(:manager, user: manager_user, partner: partner) }
  let!(:client) { create(:client, user: client_user) }
  
  let(:service_point) { create(:service_point, partner: partner) }
  
  # Make sure we have statuses
  before(:all) do
    BookingTestHelper.ensure_all_booking_statuses_exist
  end
  
  # Create a booking using our helper
  let!(:booking) do
    create_booking_with_status('pending', 
                               client: client, 
                               service_point: service_point)
  end

  before do
    # Associate manager with service_point
    create(:manager_service_point, manager: manager, service_point: service_point)
  end

  context 'being an admin' do
    let(:user) { admin_user }

    permissions :index?, :show?, :create?, :update?, :destroy?, :confirm?, :cancel?, :complete?, :no_show? do
      it 'grants access' do
        expect(subject).to permit(user, booking)
      end
    end

    permissions_for_scope :resolve do
      it 'includes all bookings' do
        scope = described_class::Scope.new(user, Booking).resolve
        expect(scope).to include(booking)
      end
    end
  end

  context 'being a partner' do
    let(:user) { partner_user }
    
    permissions :index?, :show?, :create?, :update?, :destroy?, :confirm?, :cancel?, :complete?, :no_show? do
      it 'grants access if the booking is for their service point' do
        expect(subject).to permit(user, booking)
      end
    end
    
    context 'when booking is for another partner service point' do
      let(:other_partner) { create(:partner, user: create(:user, role: partner_role)) }
      let(:other_service_point) { create(:service_point, partner: other_partner) }
      let(:other_booking) do 
        create_booking_with_status('pending', service_point: other_service_point)
      end
      
      permissions :show?, :update?, :destroy?, :confirm?, :cancel?, :complete?, :no_show? do
        it 'denies access' do
          expect(subject).not_to permit(user, other_booking)
        end
      end
    end
    
    permissions_for_scope :resolve do
      it 'includes bookings for their service points' do
        scope = described_class::Scope.new(user, Booking).resolve
        expect(scope).to include(booking)
      end
      
      it 'excludes bookings for other partners' do
        other_partner = create(:partner, user: create(:user, role: partner_role))
        other_service_point = create(:service_point, partner: other_partner)
        other_booking = create_booking_with_status('pending', service_point: other_service_point)
        
        scope = described_class::Scope.new(user, Booking).resolve
        expect(scope).not_to include(other_booking)
      end
    end
  end

  context 'being a manager' do
    let(:user) { manager_user }
    
    permissions :index?, :show?, :create?, :update?, :destroy?, :confirm?, :cancel?, :complete?, :no_show? do
      it 'grants access if the booking is for a service point they manage' do
        expect(subject).to permit(user, booking)
      end
    end
    
    context 'when booking is for a service point they do not manage' do
      let(:other_service_point) { create(:service_point, partner: partner) }
      let(:other_booking) do
        create_booking_with_status('pending', service_point: other_service_point)
      end
      
      permissions :show?, :update?, :destroy?, :confirm?, :cancel?, :complete?, :no_show? do
        it 'denies access' do
          expect(subject).not_to permit(user, other_booking)
        end
      end
    end
    
    permissions_for_scope :resolve do
      it 'includes bookings for service points they manage' do
        scope = described_class::Scope.new(user, Booking).resolve
        expect(scope).to include(booking)
      end
      
      it 'excludes bookings for service points they do not manage' do
        other_service_point = create(:service_point, partner: partner)
        other_booking = create_booking_with_status('pending', service_point: other_service_point)
        
        scope = described_class::Scope.new(user, Booking).resolve
        expect(scope).not_to include(other_booking)
      end
    end
  end

  context 'being a client' do
    let(:user) { client_user }

    permissions :index?, :show?, :create? do
      it 'grants access' do
        expect(subject).to permit(user, booking)
      end
    end
    
    permissions :update?, :destroy? do
      it 'grants access if the booking belongs to them and is pending' do
        pending_booking = create_booking_with_status('pending', client: client)
        expect(subject).to permit(user, pending_booking)
      end
      
      it 'denies access if the booking is not pending' do
        confirmed_booking = create_booking_with_status('confirmed', client: client)
        expect(subject).not_to permit(user, confirmed_booking)
      end
    end
    
    permissions :cancel? do
      it 'grants access if the booking belongs to them and is pending or confirmed' do
        pending_booking = create_booking_with_status('pending', client: client)
        expect(subject).to permit(user, pending_booking)
        
        confirmed_booking = create_booking_with_status('confirmed', client: client)
        expect(subject).to permit(user, confirmed_booking)
      end
      
      it 'denies access if the booking is completed' do
        completed_booking = create_booking_with_status('completed', client: client)
        expect(subject).not_to permit(user, completed_booking)
      end
    end
    
    permissions :confirm?, :complete?, :no_show? do
      it 'denies access' do
        expect(subject).not_to permit(user, booking)
      end
    end
    
    context 'when booking belongs to another client' do
      let(:other_client) { create(:client, user: create(:user, role: client_role)) }
      let(:other_booking) do
        create_booking_with_status('pending', client: other_client)
      end
      
      permissions :show?, :update?, :destroy?, :cancel? do
        it 'denies access' do
          expect(subject).not_to permit(user, other_booking)
        end
      end
    end
    
    permissions_for_scope :resolve do
      it 'includes only their own bookings' do
        scope = described_class::Scope.new(user, Booking).resolve
        expect(scope).to include(booking)
        
        other_client = create(:client, user: create(:user, role: client_role))
        other_booking = create_booking_with_status('pending', client: other_client)
        expect(scope).not_to include(other_booking)
      end
    end
  end

  context 'being a guest' do
    let(:user) { nil }

    permissions :index?, :show?, :create?, :update?, :destroy?, :confirm?, :cancel?, :complete?, :no_show? do
      it 'denies access' do
        expect(subject).not_to permit(user, booking)
      end
    end
    
    permissions_for_scope :resolve do
      it 'returns no bookings' do
        scope = described_class::Scope.new(user, Booking).resolve
        expect(scope).to be_empty
      end
    end
  end
end
