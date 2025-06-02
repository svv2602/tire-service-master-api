require 'rails_helper'

RSpec.describe Partner, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:managers).dependent(:destroy) }
    it { should have_many(:service_points).dependent(:destroy) }
    it { should have_many(:price_lists).dependent(:destroy) }
    it { should have_many(:promotions).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:company_name) }
    it { should validate_presence_of(:contact_person) }
    it { should validate_presence_of(:legal_address) }
    it { should validate_presence_of(:user_id) }
    
    it 'validates uniqueness of tax_number when present' do
      # Этот тест проверяет, что налоговый номер должен быть уникальным, если указан
      # Но может быть пустым (nil или '')
      expect(Partner.validators_on(:tax_number).map(&:class)).to include(ActiveRecord::Validations::UniquenessValidator)
    end
  end
end 