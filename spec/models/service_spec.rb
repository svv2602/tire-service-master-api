require 'rails_helper'

RSpec.describe Service, type: :model do
  describe 'associations' do
    it { should belong_to(:category).class_name('ServiceCategory') }
    it { should have_many(:price_list_items).dependent(:destroy) }
    it { should have_many(:booking_services).dependent(:restrict_with_error) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_numericality_of(:default_duration).is_greater_than(0) }
    
    # Дополнительные тесты валидации
    it 'validates uniqueness of name within the same category' do
      category = create(:service_category)
      create(:service, name: 'Test Service', category: category)
      
      duplicate_service = build(:service, name: 'Test Service', category: category)
      expect(duplicate_service).not_to be_valid
      expect(duplicate_service.errors[:name]).to include('has already been taken')
    end
    
    it 'allows same name in different categories' do
      category1 = create(:service_category)
      category2 = create(:service_category)
      
      create(:service, name: 'Test Service', category: category1)
      duplicate_service = build(:service, name: 'Test Service', category: category2)
      
      expect(duplicate_service).to be_valid
    end
    
    it 'validates sort_order is not negative' do
      service = build(:service, sort_order: -1)
      expect(service).not_to be_valid
      expect(service.errors[:sort_order]).to include('must be greater than or equal to 0')
    end
  end

  describe 'scopes' do
    let!(:active_service) { create(:service, is_active: true) }
    let!(:inactive_service) { create(:service, is_active: false) }
    let!(:category1) { create(:service_category) }
    let!(:category2) { create(:service_category) }
    let!(:service1) { create(:service, category: category1, sort_order: 2) }
    let!(:service2) { create(:service, category: category1, sort_order: 1) }
    let!(:service3) { create(:service, category: category2) }
    
    describe '.active' do
      it 'returns only active services' do
        expect(Service.active).to include(active_service)
        expect(Service.active).not_to include(inactive_service)
      end
    end
    
    describe '.by_category' do
      it 'returns services for the specified category' do
        expect(Service.by_category(category1.id)).to include(service1, service2)
        expect(Service.by_category(category1.id)).not_to include(service3)
      end
    end
    
    describe '.sorted' do
      it 'returns services ordered by sort_order' do
        expect(Service.where(category: category1).sorted.to_a).to eq([service2, service1])
      end
    end
  end

  describe '#current_price_for_service_point' do
    let(:partner) { create(:partner, :with_new_user) }
    let(:service_point) { create(:service_point, partner: partner) }
    let(:service) { create(:service) }
    let(:current_date) { Date.current }
    
    context 'when there is a price list item for the specific service point' do
      let!(:price_list) do
        create(:price_list, 
               service_point: service_point, 
               partner: partner, 
               is_active: true, 
               start_date: current_date - 10.days, 
               end_date: current_date + 10.days)
      end
      let!(:price_list_item) do
        create(:price_list_item, 
               price_list: price_list, 
               service: service, 
               price: 100, 
               discount_price: 80)
      end
      
      it 'returns the discount price if available' do
        expect(service.current_price_for_service_point(service_point.id)).to eq(80)
      end
      
      it 'returns the regular price if no discount price is set' do
        price_list_item.update(discount_price: nil)
        expect(service.current_price_for_service_point(service_point.id)).to eq(100)
      end
    end
    
    context 'when there is no price list item for the specific service point but there is for the partner' do
      let!(:partner_price_list) do
        create(:price_list, 
               service_point: nil, 
               partner: partner, 
               is_active: true, 
               start_date: current_date - 10.days, 
               end_date: current_date + 10.days)
      end
      let!(:partner_price_list_item) do
        create(:price_list_item, 
               price_list: partner_price_list, 
               service: service, 
               price: 120, 
               discount_price: 90)
      end
      
      it 'returns the partner level price' do
        expect(service.current_price_for_service_point(service_point.id)).to eq(90)
      end
    end
    
    context 'when there is no price list item for the service point or partner' do
      it 'returns nil' do
        expect(service.current_price_for_service_point(service_point.id)).to be_nil
      end
    end
    
    context 'when service point does not exist' do
      it 'returns nil' do
        expect(service.current_price_for_service_point(999)).to be_nil
      end
    end
    
    context 'when price list is not active' do
      let!(:inactive_price_list) do
        create(:price_list, 
               service_point: service_point, 
               partner: partner, 
               is_active: false, 
               start_date: current_date - 10.days, 
               end_date: current_date + 10.days)
      end
      let!(:price_list_item) do
        create(:price_list_item, 
               price_list: inactive_price_list, 
               service: service, 
               price: 100)
      end
      
      it 'returns nil' do
        expect(service.current_price_for_service_point(service_point.id)).to be_nil
      end
    end
    
    context 'when price list is outside the date range' do
      let!(:expired_price_list) do
        create(:price_list, 
               service_point: service_point, 
               partner: partner, 
               is_active: true, 
               start_date: current_date - 30.days, 
               end_date: current_date - 10.days)
      end
      let!(:price_list_item) do
        create(:price_list_item, 
               price_list: expired_price_list, 
               service: service, 
               price: 100)
      end
      
      it 'returns nil' do
        expect(service.current_price_for_service_point(service_point.id)).to be_nil
      end
    end
  end
end
