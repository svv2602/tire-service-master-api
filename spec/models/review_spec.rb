require 'rails_helper'

RSpec.describe Review, type: :model do
  include BookingTestHelper
  
  # Setup required statuses
  before(:all) do
    BookingTestHelper.ensure_all_booking_statuses_exist
  end
  
  describe 'associations' do
    it { should belong_to(:booking) }
    it { should belong_to(:client) }
    it { should belong_to(:service_point) }
  end

  describe 'validations' do
    it { should validate_presence_of(:rating) }
    it { should validate_numericality_of(:rating).only_integer.is_greater_than_or_equal_to(1).is_less_than_or_equal_to(5) }
    
    context 'uniqueness validation' do
      let(:service_point) { create(:service_point) }
      let(:client) { create(:client) }
      let(:booking) { create_booking_with_status('completed', service_point: service_point, client: client) }
      subject { create(:review, booking: booking, client: client, service_point: service_point) }
      
      it { should validate_uniqueness_of(:booking_id) }
    end
  end

  describe 'scopes' do
    let(:service_point) { create(:service_point) }
    let(:client) { create(:client) }
    
    let(:booking1) { create_booking_with_status('completed', service_point: service_point, client: client) }
    let(:booking2) { create_booking_with_status('completed', service_point: service_point, client: client) }
    let(:booking3) { create_booking_with_status('completed', service_point: service_point, client: client) }
    let(:booking4) { create_booking_with_status('completed', service_point: service_point, client: client) }
    
    let!(:published_review) { create(:review, booking: booking1, client: client, service_point: service_point, is_published: true) }
    let!(:unpublished_review) { create(:review, booking: booking2, client: client, service_point: service_point, is_published: false) }
    
    # Create reviews with specific creation dates
    let!(:old_review) do
      review = create(:review, booking: booking3, client: client, service_point: service_point)
      # Update the created_at timestamp
      review.update_column(:created_at, 2.days.ago)
      review
    end
    
    let!(:new_review) do
      review = create(:review, booking: booking4, client: client, service_point: service_point)
      # Update the created_at timestamp
      review.update_column(:created_at, 1.day.ago)
      review
    end

    describe '.published' do
      it 'returns only published reviews' do
        expect(Review.published).to include(published_review)
        expect(Review.published).not_to include(unpublished_review)
      end
    end

    describe '.ordered_by_date' do
      it 'returns reviews ordered by creation date' do
        sorted_reviews = Review.ordered_by_date.to_a
        # Compare just the order - exact object comparisons can be problematic
        # Confirm newer reviews come before older ones
        expect(sorted_reviews.pluck(:created_at)).to eq(sorted_reviews.pluck(:created_at).sort.reverse)
      end
    end
  end

  describe 'callbacks' do
    let(:service_point) { create(:service_point) }
    let(:client) { create(:client) }
    let(:booking) { create_booking_with_status('completed', service_point: service_point, client: client) }
    
    context 'after save' do
      it 'updates the service point rating' do
        expect_any_instance_of(ServicePoint).to receive(:recalculate_metrics!)
        create(:review, booking: booking, client: client, service_point: service_point)
      end
    end
    
    context 'after destroy' do
      it 'updates the service point rating' do
        review = create(:review, booking: booking, client: client, service_point: service_point)
        
        # Use allow instead of expect to avoid counting the call from the after_save callback
        allow_any_instance_of(ServicePoint).to receive(:recalculate_metrics!)
        
        # Reset the expectation for the destroy callback
        expect_any_instance_of(ServicePoint).to receive(:recalculate_metrics!)
        
        review.destroy
      end
    end
  end
end
