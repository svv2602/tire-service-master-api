require 'rails_helper'

RSpec.describe User, type: :model do
  let(:admin_role) { UserRole.find_or_create_by(name: 'admin') { |role| role.description = 'Administrator role with full access' } }
  let(:manager_role) { UserRole.find_or_create_by(name: 'manager') { |role| role.description = 'Manager role for service point managers' } }
  let(:partner_role) { UserRole.find_or_create_by(name: 'partner') { |role| role.description = 'Partner role for service point owners' } }
  let(:client_role) { UserRole.find_or_create_by(name: 'client') { |role| role.description = 'Client role for users who book services' } }

  describe 'associations' do
    it { should have_one(:client).dependent(:destroy) }
    it { should have_one(:manager).dependent(:destroy) }
    it { should have_one(:partner).dependent(:destroy) }
    it { should have_one(:administrator).dependent(:destroy) }
    it { should have_many(:system_logs).dependent(:nullify) }
    it { should belong_to(:role).class_name('UserRole') }
  end

  describe 'validations' do
    subject { build(:user, role: client_role) }
    
    # Email валидация
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    
    describe 'email format validation' do
      it 'accepts valid email formats' do
        valid_emails = ['user@example.com', 'test.email+tag@example.org', 'user123@test-domain.co.uk']
        valid_emails.each do |email|
          user = build(:user, email: email, role: client_role)
          expect(user).to be_valid
        end
      end
      
      it 'rejects invalid email formats' do
        invalid_emails = ['invalid', '@example.com', 'user@']
        invalid_emails.each do |email|
          user = build(:user, email: email, role: client_role, phone: nil)
          expect(user).not_to be_valid, "Expected #{email} to be invalid"
          expect(user.errors[:email]).to be_present
        end
      end
    end
    
    # Пароль валидация
    it { should validate_presence_of(:password).on(:create) }
    it { should validate_length_of(:password).is_at_least(6).on(:create) }
    it { should validate_confirmation_of(:password) }
    
    describe 'password validation' do
      it 'accepts strong passwords' do
        user = build(:user, password: 'StrongPassword123!', password_confirmation: 'StrongPassword123!', role: client_role)
        expect(user).to be_valid
      end
      
      it 'rejects weak passwords' do
        weak_passwords = ['123', 'pass', '12345']
        weak_passwords.each do |password|
          user = build(:user, password: password, password_confirmation: password, role: client_role)
          expect(user).not_to be_valid
          expect(user.errors[:password]).to be_present
        end
      end
      
      it 'does not require password on update if not changing' do
        user = create(:user, role: client_role)
        user.first_name = 'Updated Name'
        expect(user).to be_valid
      end
    end
    
    # Роль валидация
    it { should validate_presence_of(:role_id) }
    
    # Имя и фамилия валидация
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_length_of(:first_name).is_at_least(2).is_at_most(50) }
    it { should validate_length_of(:last_name).is_at_least(2).is_at_most(50) }
    
    # Телефон валидация
    describe 'phone validation' do
      it 'accepts valid phone formats' do
        valid_phones = ['+380991234567', '+1234567890']
        valid_phones.each do |phone|
          user = build(:user, phone: phone, role: client_role)
          expect(user).to be_valid
        end
      end
      
      it 'accepts nil phone' do
        user = build(:user, phone: nil, role: client_role)
        expect(user).to be_valid
      end
    end
  end

  describe 'default values' do
    it 'sets default values on creation' do
      user = create(:user, role: client_role)
      expect(user.is_active).to be true
      expect(user.email_verified).to be true
      expect(user.phone_verified).to be false
    end
  end

  describe 'role checking methods' do
    describe '#client?' do
      it 'returns true when user role is client' do
        user = create(:user, role: client_role)
        expect(user.client?).to be true
      end
      
      it 'returns false when user role is not client' do
        user = create(:user, role: admin_role)
        expect(user.client?).to be false
      end
    end

    describe '#manager?' do
      it 'returns true when user role is manager' do
        user = create(:user, role: manager_role)
        expect(user.manager?).to be true
      end
      
      it 'returns false when user role is not manager' do
        user = create(:user, role: admin_role)
        expect(user.manager?).to be false
      end
    end

    describe '#partner?' do
      it 'returns true when user role is partner' do
        user = create(:user, role: partner_role)
        expect(user.partner?).to be true
      end
      
      it 'returns false when user role is not partner' do
        user = create(:user, role: admin_role)
        expect(user.partner?).to be false
      end
    end

    describe '#admin?' do
      it 'returns true when user role is admin' do
        user = create(:user, role: admin_role)
        expect(user.admin?).to be true
      end
      
      it 'returns false when user role is not admin' do
        user = create(:user, role: client_role)
        expect(user.admin?).to be false
      end
    end
  end

  describe 'scopes' do
    before do
      create_list(:user, 3, role: client_role, is_active: true)
      create_list(:user, 2, role: client_role, is_active: false)
      create_list(:user, 2, role: admin_role, is_active: true)
      create_list(:user, 1, role: partner_role, is_active: true)
    end

    describe '.active' do
      it 'returns only active users' do
        active_users = User.active
        expect(active_users.count).to eq(6)
        expect(active_users.all?(&:is_active)).to be true
      end
    end

    describe '.inactive' do
      it 'returns only inactive users' do
        inactive_users = User.inactive
        expect(inactive_users.count).to eq(2)
        expect(inactive_users.all? { |u| !u.is_active }).to be true
      end
    end

    describe '.by_role' do
      it 'filters users by role' do
        client_users = User.by_role('client')
        expect(client_users.count).to eq(5)
        expect(client_users.all?(&:client?)).to be true
      end

      it 'filters partners by role' do
        partner_users = User.by_role('partner')
        expect(partner_users.count).to eq(1)
        expect(partner_users.all?(&:partner?)).to be true
      end
    end
  end

  describe 'callbacks' do
    describe 'before_save' do
      it 'normalizes email to lowercase' do
        user = create(:user, email: 'TEST@EXAMPLE.COM', role: client_role)
        expect(user.email).to eq('test@example.com')
      end

      it 'normalizes phone format' do
        user = create(:user, phone: '+38 (099) 123-45-67', role: client_role)
        expect(user.phone).to eq('+380991234567')
      end
    end

    describe 'after_create' do
      it 'creates associated client record for client role' do
        user = create(:user, role: client_role)
        expect(user.client).to be_present
      end

      it 'creates associated manager record for manager role' do
        user = create(:user, role: manager_role)
        expect(user.manager).to be_present
      end

      it 'creates associated partner record for partner role' do
        user = create(:user, role: partner_role)
        expect(user.partner).to be_present
      end

      it 'creates associated administrator record for admin role' do
        user = create(:user, role: admin_role)
        expect(user.administrator).to be_present
      end
    end
  end

  describe 'instance methods' do
    let(:user) { create(:user, first_name: 'Иван', last_name: 'Петров', middle_name: 'Сидорович', role: client_role) }

    describe '#full_name' do
      it 'returns full name with middle name' do
        expect(user.full_name).to eq('Петров Иван Сидорович')
      end

      it 'returns full name without middle name' do
        user.middle_name = nil
        expect(user.full_name).to eq('Иван Петров')
      end
    end

    describe '#deactivate!' do
      it 'sets is_active to false' do
        user.deactivate!
        expect(user.is_active).to be false
      end

      it 'saves the user' do
        expect { user.deactivate! }.to change { user.reload.is_active }.from(true).to(false)
      end
    end

    describe '#activate!' do
      before { user.update!(is_active: false) }

      it 'sets is_active to true' do
        user.activate!
        expect(user.is_active).to be true
      end

      it 'saves the user' do
        expect { user.activate! }.to change { user.reload.is_active }.from(false).to(true)
      end
    end

    describe '#verify_email!' do
      it 'sets email_verified to true' do
        user.verify_email!
        expect(user.email_verified).to be true
      end
    end

    describe '#verify_phone!' do
      it 'sets phone_verified to true' do
        user.verify_phone!
        expect(user.phone_verified).to be true
      end
    end

    describe '#can_be_deleted_by?' do
      let(:admin_user) { create(:user, role: admin_role) }
      let(:other_admin) { create(:user, role: admin_role) }

      it 'returns true when admin deletes non-admin user' do
        expect(user.can_be_deleted_by?(admin_user)).to be true
      end

      it 'returns false when admin tries to delete themselves' do
        expect(admin_user.can_be_deleted_by?(admin_user)).to be false
      end

      it 'returns true when admin deletes another admin' do
        expect(other_admin.can_be_deleted_by?(admin_user)).to be true
      end

      it 'returns false when non-admin tries to delete user' do
        expect(user.can_be_deleted_by?(create(:user, role: client_role))).to be false
      end
    end
  end

  describe 'search functionality' do
    before do
      create(:user, first_name: 'Александр', last_name: 'Петров', email: 'alex@test.com', role: client_role)
      create(:user, first_name: 'Мария', last_name: 'Александрова', email: 'maria@test.com', role: client_role)
      create(:user, first_name: 'Иван', last_name: 'Сидоров', email: 'ivan@example.com', role: client_role)
    end

    describe '.search' do
      it 'finds users by first name' do
        results = User.search('александр')
        expect(results.count).to eq(2)
      end

      it 'finds users by last name' do
        results = User.search('петров')
        expect(results.count).to eq(1)
      end

      it 'finds users by email' do
        results = User.search('test.com')
        expect(results.count).to eq(2)
      end

      it 'is case insensitive' do
        results = User.search('АЛЕКСАНДР')
        expect(results.count).to eq(2)
      end

      it 'returns all users when query is empty' do
        results = User.search('')
        expect(results.count).to eq(User.count)
      end
    end
  end
end
