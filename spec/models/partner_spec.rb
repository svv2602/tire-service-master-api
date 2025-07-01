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

  describe 'logo attachment' do
    let(:partner) { create(:partner) }
    
    it 'should have one attached logo' do
      expect(partner).to respond_to(:logo)
      expect(partner.logo).to be_an_instance_of(ActiveStorage::Attached::One)
    end

    context 'logo validation' do
      it 'accepts valid image formats' do
        valid_formats = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp']
        
        valid_formats.each do |format|
          partner.logo.attach(
            io: StringIO.new('fake image data'),
            filename: "test.#{format.split('/').last}",
            content_type: format
          )
          expect(partner).to be_valid
          partner.logo.purge
        end
      end

      it 'rejects files larger than 5MB' do
        # Создаем файл размером больше 5MB
        large_file = StringIO.new('x' * (5.megabytes + 1))
        
        partner.logo.attach(
          io: large_file,
          filename: 'large_image.jpg',
          content_type: 'image/jpeg'
        )
        
        expect(partner).not_to be_valid
        expect(partner.errors[:logo]).to include('слишком большой размер (не более 5MB)')
      end

      it 'rejects invalid file formats' do
        partner.logo.attach(
          io: StringIO.new('fake data'),
          filename: 'document.pdf',
          content_type: 'application/pdf'
        )
        
        expect(partner).not_to be_valid
        expect(partner.errors[:logo]).to include('должен быть изображением (JPEG, PNG, GIF, WebP)')
      end
    end
  end
end 