require 'rails_helper'

RSpec.describe ServicePoint, type: :model do
  describe 'associations' do
    it { should belong_to(:partner) }
    it { should belong_to(:city) }
    it { should have_many(:service_posts).dependent(:destroy) }
    it { should have_many(:photos).class_name('ServicePointPhoto').dependent(:destroy) }
    it { should have_many(:service_point_amenities).dependent(:destroy) }
    it { should have_many(:amenities).through(:service_point_amenities) }
    it { should have_many(:manager_service_points).dependent(:destroy) }
    it { should have_many(:managers).through(:manager_service_points) }
    it { should have_many(:schedule_templates).dependent(:destroy) }
    it { should have_many(:schedule_exceptions).dependent(:destroy) }
    it { should have_many(:schedule_slots).dependent(:destroy) }
    it { should have_many(:bookings).dependent(:restrict_with_error) }
    it { should have_many(:reviews).dependent(:destroy) }
    it { should have_many(:price_lists).dependent(:destroy) }
    it { should have_many(:promotions).dependent(:destroy) }
    it { should have_many(:client_favorite_points).dependent(:destroy) }
    it { should have_many(:favorited_by_clients).through(:client_favorite_points).source(:client) }
  end

  describe 'validations' do
    subject { build(:service_point) }
    
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:address) }
    it { should validate_numericality_of(:latitude).is_greater_than_or_equal_to(-90).is_less_than_or_equal_to(90).allow_nil }
    it { should validate_numericality_of(:longitude).is_greater_than_or_equal_to(-180).is_less_than_or_equal_to(180).allow_nil }
    it { should validate_presence_of(:work_status) }
  end

  describe 'enums' do
    it { should define_enum_for(:work_status).with_values(
      working: 'working',
      temporarily_closed: 'temporarily_closed',
      maintenance: 'maintenance',
      suspended: 'suspended'
    ).backed_by_column_of_type(:string)}
  end

  describe 'scopes' do
    let(:partner) { create(:partner, :with_new_user) }
    let(:city) { create(:city) }
    let!(:active_point) { create(:service_point, is_active: true, work_status: 'working', partner: partner, city: city) }
    let!(:inactive_point) { create(:service_point, is_active: false, work_status: 'suspended') }
    let!(:maintenance_point) { create(:service_point, is_active: true, work_status: 'maintenance') }
    let!(:other_partner_point) { create(:service_point, partner: create(:partner, :with_new_user)) }
    let!(:other_city_point) { create(:service_point, city: create(:city)) }
    let(:amenity1) { create(:amenity) }
    let(:amenity2) { create(:amenity) }
    let!(:point_with_amenities) do
      point = create(:service_point)
      create(:service_point_amenity, service_point: point, amenity: amenity1)
      create(:service_point_amenity, service_point: point, amenity: amenity2)
      point
    end
    let!(:point_with_partial_amenities) do 
      point = create(:service_point)
      create(:service_point_amenity, service_point: point, amenity: amenity1)
      point
    end

    describe '.active' do
      it 'returns only active service points' do
        expect(ServicePoint.active).to include(active_point)
        expect(ServicePoint.active).not_to include(inactive_point)
      end
    end

    describe '.by_city' do
      it 'returns only service points in the specified city' do
        expect(ServicePoint.by_city(city.id)).to include(active_point)
        expect(ServicePoint.by_city(city.id)).not_to include(other_city_point)
      end
    end

    describe '.by_partner' do
      it 'returns only service points for the specified partner' do
        expect(ServicePoint.by_partner(partner.id)).to include(active_point)
        expect(ServicePoint.by_partner(partner.id)).not_to include(other_partner_point)
      end
    end

    describe '.with_amenities' do
      it 'returns service points with all specified amenities' do
        expect(ServicePoint.with_amenities([amenity1.id, amenity2.id])).to include(point_with_amenities)
        expect(ServicePoint.with_amenities([amenity1.id, amenity2.id])).not_to include(point_with_partial_amenities)
      end

      it 'returns service points with any of the specified amenities' do
        expect(ServicePoint.with_amenities([amenity1.id])).to include(point_with_amenities, point_with_partial_amenities)
      end
    end

    describe '.near' do
      let!(:nearby_point) { create(:service_point, latitude: 55.7558, longitude: 37.6173) }
      let!(:distant_point) { create(:service_point, latitude: 59.9343, longitude: 30.3351) }

      it 'returns service points within the specified radius' do
        near_points = ServicePoint.near(55.7558, 37.6173, 10)
        expect(near_points).to include(nearby_point)
        expect(near_points).not_to include(distant_point)
      end
    end
  end

  describe 'status methods' do
    let(:working_point) { create(:service_point, is_active: true, work_status: 'working') }
    let(:temporarily_closed_point) { create(:service_point, is_active: true, work_status: 'temporarily_closed') }
    let(:maintenance_point) { create(:service_point, is_active: true, work_status: 'maintenance') }
    let(:suspended_point) { create(:service_point, is_active: false, work_status: 'suspended') }

    describe '#active?' do
      it 'returns true when is_active is true' do
        expect(working_point.active?).to be true
        expect(suspended_point.active?).to be false
      end
    end

    describe '#working?' do
      it 'returns true when work_status is working' do
        expect(working_point.working?).to be true
        expect(temporarily_closed_point.working?).to be false
      end
    end

    describe '#temporarily_closed?' do
      it 'returns true when work_status is temporarily_closed' do
        expect(temporarily_closed_point.temporarily_closed?).to be true
        expect(working_point.temporarily_closed?).to be false
      end
    end

    describe '#maintenance?' do
      it 'returns true when work_status is maintenance' do
        expect(maintenance_point.maintenance?).to be true
        expect(working_point.maintenance?).to be false
      end
    end

    describe '#suspended?' do
      it 'returns true when work_status is suspended' do
        expect(suspended_point.suspended?).to be true
        expect(working_point.suspended?).to be false
      end
    end
  end

  describe '#display_status' do
    let(:working_point) { create(:service_point, work_status: 'working') }
    let(:temporarily_closed_point) { create(:service_point, work_status: 'temporarily_closed') }

    it 'returns localized status display' do
      expect(working_point.display_status).to be_present
      expect(temporarily_closed_point.display_status).to be_present
    end
  end

  describe '#recalculate_metrics!' do
    let(:service_point) { create(:service_point) }
    let(:client) { create(:client) }
    
    # Instead of creating booking_status records, we'll ensure they exist with our helper
    before do
      ensure_booking_statuses_exist
    end
    
    let!(:completed_booking1) { create_booking_with_status('completed', service_point: service_point) }
    let!(:completed_booking2) { create_booking_with_status('completed', service_point: service_point) }
    let!(:canceled_booking) { create_booking_with_status('canceled_by_client', service_point: service_point) }
    let!(:no_show_booking) { create_booking_with_status('no_show', service_point: service_point) }
    
    let!(:review1) { create(:review, service_point: service_point, rating: 4, booking: completed_booking1) }
    let!(:review2) { create(:review, service_point: service_point, rating: 5, booking: completed_booking2) }
    
    it 'updates total_clients_served correctly' do
      service_point.recalculate_metrics!
      expect(service_point.total_clients_served).to eq(2) # only completed bookings
    end

    it 'updates average_rating correctly' do
      service_point.recalculate_metrics!
      expect(service_point.average_rating).to eq(4.5) # (4 + 5) / 2
    end

    it 'updates cancellation_rate correctly' do
      service_point.recalculate_metrics!
      expect(service_point.cancellation_rate).to eq(50.0) # (2 canceled out of 4 total) * 100
    end

    context 'when there are no reviews' do
      let(:service_point_without_reviews) { create(:service_point) }

      it 'sets average_rating to 0' do
        service_point_without_reviews.recalculate_metrics!
        expect(service_point_without_reviews.average_rating).to eq(0.0)
      end
    end

    context 'when there are no bookings' do
      let(:service_point_without_bookings) { create(:service_point) }

      it 'sets cancellation_rate to 0' do
        service_point_without_bookings.recalculate_metrics!
        expect(service_point_without_bookings.cancellation_rate).to eq(0.0)
      end
    end
  end
end
