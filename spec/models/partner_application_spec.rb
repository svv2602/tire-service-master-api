require 'rails_helper'

RSpec.describe PartnerApplication, type: :model do
  describe 'associations' do
    it { should belong_to(:region).optional }
    it { should belong_to(:city_record).class_name('City').optional }
    it { should belong_to(:processed_by).class_name('User').optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:company_name) }
    it { should validate_length_of(:company_name).is_at_least(2).is_at_most(100) }
    
    it { should validate_presence_of(:business_description) }
    it { should validate_length_of(:business_description).is_at_least(10).is_at_most(1000) }
    
    it { should validate_presence_of(:contact_person) }
    it { should validate_length_of(:contact_person).is_at_least(2).is_at_most(100) }
    
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    
    it { should validate_presence_of(:phone) }
    it { should validate_presence_of(:city) }
    it { should validate_length_of(:city).is_at_least(2).is_at_most(50) }
    
    it { should validate_presence_of(:expected_service_points) }
    it { should validate_numericality_of(:expected_service_points).only_integer.is_greater_than(0).is_less_than(100) }
    
    it { should validate_presence_of(:status) }

    describe 'email format validation' do
      let(:application) { build(:partner_application) }

      it 'accepts valid email' do
        application.email = 'test@example.com'
        expect(application).to be_valid
      end

      it 'rejects invalid email' do
        application.email = 'invalid-email'
        expect(application).not_to be_valid
        expect(application.errors[:email]).to include('is invalid')
      end
    end

    describe 'phone format validation' do
      let(:application) { build(:partner_application) }

      it 'accepts valid phone with plus' do
        application.phone = '+380671234567'
        expect(application).to be_valid
      end

      it 'accepts valid phone without plus' do
        application.phone = '380671234567'
        expect(application).to be_valid
      end

      it 'rejects invalid phone' do
        application.phone = '123'
        expect(application).not_to be_valid
        expect(application.errors[:phone]).to include('is invalid')
      end
    end
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(pending: 'new', in_progress: 'in_progress', approved: 'approved', rejected: 'rejected', connected: 'connected') }
  end

  describe 'scopes' do
    let!(:pending_app) { create(:partner_application, status: 'new') }
    let!(:approved_app) { create(:partner_application, status: 'approved') }
    let!(:processed_app) { create(:partner_application, status: 'approved', processed_at: 1.day.ago) }
    let!(:unprocessed_app) { create(:partner_application, status: 'new', processed_at: nil) }

    describe '.by_status' do
      it 'filters by status' do
        expect(PartnerApplication.by_status('new')).to include(pending_app)
        expect(PartnerApplication.by_status('new')).not_to include(approved_app)
      end
    end

    describe '.recent' do
      it 'orders by created_at desc' do
        expect(PartnerApplication.recent.first).to eq(unprocessed_app)
      end
    end

    describe '.processed' do
      it 'returns only processed applications' do
        expect(PartnerApplication.processed).to include(processed_app)
        expect(PartnerApplication.processed).not_to include(unprocessed_app)
      end
    end

    describe '.unprocessed' do
      it 'returns only unprocessed applications' do
        expect(PartnerApplication.unprocessed).to include(unprocessed_app)
        expect(PartnerApplication.unprocessed).not_to include(processed_app)
      end
    end
  end

  describe 'callbacks' do
    describe 'before_validation' do
      let(:application) { build(:partner_application, email: ' TEST@EXAMPLE.COM ', phone: '+38 (067) 123-45-67') }

      it 'normalizes email' do
        application.valid?
        expect(application.email).to eq('test@example.com')
      end

      it 'normalizes phone' do
        application.valid?
        expect(application.phone).to eq('+380671234567')
      end
    end

    describe 'after_update' do
      let(:application) { create(:partner_application, status: 'new') }

      it 'sets processed_at when status changes' do
        expect(application.processed_at).to be_nil
        application.update!(status: 'in_progress')
        expect(application.processed_at).to be_present
      end
    end
  end

  describe 'instance methods' do
    let(:user) { create(:user, :admin) }
    let(:manager) { create(:user, :manager) }
    let(:client) { create(:user, :client) }
    let(:application) { create(:partner_application) }

    describe '#can_be_processed_by?' do
      it 'returns true for admin' do
        expect(application.can_be_processed_by?(user)).to be true
      end

      it 'returns true for manager' do
        expect(application.can_be_processed_by?(manager)).to be true
      end

      it 'returns false for client' do
        expect(application.can_be_processed_by?(client)).to be false
      end
    end

    describe '#full_address' do
      it 'combines city and address' do
        application.city = 'Київ'
        application.address = 'вул. Хрещатик, 1'
        expect(application.full_address).to eq('Київ, вул. Хрещатик, 1')
      end

      it 'returns only city when address is blank' do
        application.city = 'Київ'
        application.address = nil
        expect(application.full_address).to eq('Київ')
      end
    end

    describe '#processed?' do
      it 'returns true when processed_at is present' do
        application.processed_at = Time.current
        expect(application.processed?).to be true
      end

      it 'returns false when processed_at is nil' do
        application.processed_at = nil
        expect(application.processed?).to be false
      end
    end

    describe '#status_label' do
      it 'returns correct labels' do
        application.status = 'new'
        expect(application.status_label).to eq('Новая')
        
        application.status = 'in_progress'
        expect(application.status_label).to eq('В работе')
        
        application.status = 'approved'
        expect(application.status_label).to eq('Одобрена')
        
        application.status = 'rejected'
        expect(application.status_label).to eq('Отклонена')
        
        application.status = 'connected'
        expect(application.status_label).to eq('Подключен')
      end
    end

    describe '#status_color' do
      it 'returns correct colors' do
        application.status = 'new'
        expect(application.status_color).to eq('info')
        
        application.status = 'in_progress'
        expect(application.status_color).to eq('warning')
        
        application.status = 'approved'
        expect(application.status_color).to eq('success')
        
        application.status = 'rejected'
        expect(application.status_color).to eq('error')
        
        application.status = 'connected'
        expect(application.status_color).to eq('success')
      end
    end

    describe 'status change methods' do
      let(:admin) { create(:user, :admin) }

      describe '#mark_as_in_progress!' do
        it 'changes status and sets processed_by' do
          application.mark_as_in_progress!(admin)
          expect(application.status).to eq('in_progress')
          expect(application.processed_by).to eq(admin)
        end
      end

      describe '#approve!' do
        it 'changes status, sets processed_by and notes' do
          notes = 'Отличная компания'
          application.approve!(admin, notes)
          expect(application.status).to eq('approved')
          expect(application.processed_by).to eq(admin)
          expect(application.admin_notes).to eq(notes)
        end
      end

      describe '#reject!' do
        it 'changes status, sets processed_by and notes' do
          notes = 'Недостаточно документов'
          application.reject!(admin, notes)
          expect(application.status).to eq('rejected')
          expect(application.processed_by).to eq(admin)
          expect(application.admin_notes).to eq(notes)
        end
      end

      describe '#mark_as_connected!' do
        it 'changes status, sets processed_by and notes' do
          notes = 'Партнер успешно подключен'
          application.mark_as_connected!(admin, notes)
          expect(application.status).to eq('connected')
          expect(application.processed_by).to eq(admin)
          expect(application.admin_notes).to eq(notes)
        end
      end
    end
  end
end 