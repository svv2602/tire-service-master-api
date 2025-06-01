require 'rails_helper'

RSpec.describe ServiceCategory, type: :model do
  # Добавляем subject для shoulda-matchers
  subject { build(:service_category) }

  describe 'associations' do
    it { should have_many(:services).with_foreign_key('category_id').dependent(:restrict_with_error) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
  end

  describe 'scopes' do
    describe '.active' do
      let!(:active_category) { create(:service_category, is_active: true) }
      let!(:inactive_category) { create(:service_category, is_active: false) }
      
      it 'returns only active categories' do
        expect(ServiceCategory.active).to include(active_category)
        expect(ServiceCategory.active).not_to include(inactive_category)
      end
    end
    
    describe '.sorted' do
      before { ServiceCategory.destroy_all }
      let!(:category1) { create(:service_category, name: 'Category A', sort_order: 2) }
      let!(:category2) { create(:service_category, name: 'Category B', sort_order: 1) }
      
      it 'returns categories ordered by sort_order' do
        sorted_categories = ServiceCategory.sorted.to_a
        expect(sorted_categories).to eq([category2, category1])
      end
    end
  end

  describe '#services_count' do
    let(:category) { create(:service_category) }
    
    it 'returns 0 when category has no services' do
      expect(category.services_count).to eq(0)
    end
    
    it 'returns correct count when category has services' do
      create_list(:service, 3, category: category)
      expect(category.services_count).to eq(3)
    end
    
    it 'counts both active and inactive services' do
      create(:service, category: category, is_active: true)
      create(:service, category: category, is_active: false)
      expect(category.services_count).to eq(2)
    end
  end

  describe '#as_json' do
    let(:category) { create(:service_category, name: "Test Category", description: "Test Description") }
    
    context 'without include_services_count option' do
      it 'returns basic category data' do
        json = category.as_json
        
        expect(json).to include(
          'id' => category.id,
          'name' => "Test Category",
          'description' => "Test Description",
          'is_active' => category.is_active,
          'sort_order' => category.sort_order
        )
        expect(json).not_to have_key('services_count')
      end
    end
    
    context 'with include_services_count option' do
      it 'includes services_count in the response' do
        create_list(:service, 2, category: category)
        json = category.as_json(include_services_count: true)
        
        expect(json).to include(
          'id' => category.id,
          'name' => "Test Category",
          'services_count' => 2
        )
      end
    end
  end

  describe 'dependent destroy behavior' do
    let(:category) { create(:service_category) }
    
    context 'when category has no services' do
      it 'can be destroyed' do
        # Сначала создаем категорию, чтобы она была в базе
        category_to_destroy = create(:service_category)
        expect { category_to_destroy.destroy }.to change(ServiceCategory, :count).by(-1)
        expect(category_to_destroy.destroyed?).to be true
      end
    end
    
    context 'when category has services' do
      before do
        create(:service, category: category)
      end
      
      it 'cannot be destroyed and raises error when using destroy!' do
        expect { category.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
      end
      
      it 'adds error to the model when destroy fails' do
        expect(category.destroy).to be false
        expect(category.errors).to be_present
        expect(ServiceCategory.exists?(category.id)).to be true
      end
    end
  end

  describe 'database constraints' do
    let(:category) { create(:service_category) }
    
    it 'enforces name uniqueness at database level' do
      expect {
        # Создаем запись напрямую через SQL, обходя валидации Rails
        ActiveRecord::Base.connection.execute(
          "INSERT INTO service_categories (name, created_at, updated_at) VALUES ('#{category.name}', NOW(), NOW())"
        )
      }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  describe 'factory' do
    it 'creates valid category with factory' do
      category = create(:service_category)
      expect(category).to be_valid
      expect(category.name).to be_present
      expect(category.is_active).to be true
    end
    
    it 'creates inactive category with trait' do
      category = create(:service_category, :inactive)
      expect(category.is_active).to be false
    end
    
    it 'creates category with services using trait' do
      category = create(:service_category, :with_services)
      expect(category.services.count).to eq(3)
    end
  end
end
