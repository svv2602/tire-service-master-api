require 'rails_helper'

RSpec.describe BookingService, type: :model do
  include BookingTestHelper
  
  # Setup required statuses
  before(:all) do
    BookingTestHelper.ensure_all_booking_statuses_exist
  end
  
  describe 'associations' do
    it { should belong_to(:booking) }
    it { should belong_to(:service) }
  end

  describe 'validations' do
    it { should validate_presence_of(:price) }
    it { should validate_numericality_of(:price).is_greater_than_or_equal_to(0) }
    it { should validate_presence_of(:quantity) }
    it { should validate_numericality_of(:quantity).is_greater_than(0) }
  end

  describe 'delegations' do
    let(:service) { create(:service, name: 'Test Service') }
    let(:booking) { create_booking_with_status('pending') }
    let(:booking_service) { create(:booking_service, service: service, booking: booking) }
    
    it 'delegates name to service with prefix' do
      expect(booking_service.service_name).to eq('Test Service')
    end
  end

  describe '#total_price' do
    let(:service) { create(:service) }
    let(:booking) { create_booking_with_status('pending') }
    let(:booking_service) { create(:booking_service, price: 1000, quantity: 2, booking: booking, service: service) }
    
    it 'calculates the total price' do
      expect(booking_service.total_price).to eq(2000)
    end
    
    it 'recalculates when price changes' do
      booking_service.price = 1500
      expect(booking_service.total_price).to eq(3000)
    end
    
    it 'recalculates when quantity changes' do
      booking_service.quantity = 3
      expect(booking_service.total_price).to eq(3000)
    end
  end
end
