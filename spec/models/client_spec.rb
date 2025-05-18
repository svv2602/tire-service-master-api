require 'rails_helper'

RSpec.describe Client, type: :model do
  include BookingTestHelper

  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:cars).class_name('ClientCar').dependent(:destroy) }
    it { should have_many(:bookings).dependent(:nullify) }
    it { should have_many(:reviews).dependent(:nullify) }
    it { should have_many(:favorite_points).class_name('ClientFavoritePoint').dependent(:destroy) }
    it { should have_many(:favorite_service_points).through(:favorite_points).source(:service_point) }
  end

  describe 'validations' do
    it { should validate_presence_of(:user_id) }
    
    context 'uniqueness validation' do
      subject { build(:client) }
      before { create(:client) }
      it { should validate_uniqueness_of(:user_id) }
    end
    
    it { should validate_inclusion_of(:preferred_notification_method).in_array(['push', 'email', 'sms']) }
  end

  describe '#primary_car' do
    let(:client) { create(:client, :with_cars) }
    
    it 'returns the primary car' do
      primary_car = client.cars.find_by(is_primary: true)
      expect(client.primary_car).to eq(primary_car)
    end
    
    context 'when there is no primary car' do
      let(:client_without_primary) { create(:client) }
      
      before do
        # Создаем уникальные бренд и модель для теста
        brand = create(:car_brand, name: "TestBrand-#{Time.now.to_i}-#{SecureRandom.hex(4)}")
        model = create(:car_model, brand: brand, name: "TestModel-#{Time.now.to_i}-#{SecureRandom.hex(4)}")
        create(:client_car, client: client_without_primary, brand: brand, model: model, is_primary: false)
      end
      
      it 'returns nil' do
        expect(client_without_primary.primary_car).to be_nil
      end
    end
  end
  
  describe '#total_bookings' do
    let(:client) { create(:client) }
    
    before do
      # Ensure all booking statuses exist
      ensure_booking_statuses_exist
      
      # Create bookings with valid statuses for the client
      3.times do
        create_booking_with_status('pending', client: client)
      end
    end
    
    it 'returns the count of all bookings' do
      expect(client.total_bookings).to eq(3)
    end
    
    context 'when there are no bookings' do
      let(:client_without_bookings) { create(:client) }
      
      it 'returns 0' do
        expect(client_without_bookings.total_bookings).to eq(0)
      end
    end
  end
  
  describe '#completed_bookings' do
    let(:client) { create(:client) }
    let(:completed_status) { create(:booking_status, name: 'completed') }
    let(:pending_status) { create(:booking_status, name: 'pending') }
    
    let!(:completed_booking1) { create(:booking, client: client, status: completed_status) }
    let!(:completed_booking2) { create(:booking, client: client, status: completed_status) }
    let!(:pending_booking) { create(:booking, client: client, status: pending_status) }
    
    before do
      allow(BookingStatus).to receive(:completed_id).and_return(completed_status.id)
    end
    
    it 'returns the count of completed bookings' do
      expect(client.completed_bookings).to eq(2)
    end
    
    context 'when there are no completed bookings' do
      let(:client_without_completed) { create(:client) }
      let!(:pending_booking) { create(:booking, client: client_without_completed, status: pending_status) }
      
      it 'returns 0' do
        expect(client_without_completed.completed_bookings).to eq(0)
      end
    end
  end
  
  describe '#average_rating_given' do
    include BookingTestHelper
    
    let(:client) { create(:client) }
    
    before do
      # Ensure all booking statuses exist
      ensure_booking_statuses_exist
      
      # Create completed bookings for the reviews
      @booking1 = create_booking_with_status('completed', client: client)
      @booking2 = create_booking_with_status('completed', client: client)
      
      # Create reviews using the completed bookings
      @review1 = Review.create!(
        booking: @booking1,
        client: client,
        service_point: @booking1.service_point,
        rating: 4,
        comment: "Good service",
        is_published: true
      )
      
      @review2 = Review.create!(
        booking: @booking2,
        client: client,
        service_point: @booking2.service_point,
        rating: 5,
        comment: "Excellent service",
        is_published: true
      )
    end
    
    it 'returns the average rating given in reviews' do
      expect(client.average_rating_given).to eq(4.5)
    end
    
    context 'when there are no reviews' do
      let(:client_without_reviews) { create(:client) }
      
      it 'returns 0.0' do
        expect(client_without_reviews.average_rating_given).to eq(0.0)
      end
    end
  end
end
