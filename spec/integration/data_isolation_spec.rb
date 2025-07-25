require 'rails_helper'

RSpec.describe 'Data Isolation', type: :request do
  # Создаем роли
  let(:admin_role) { UserRole.find_or_create_by(name: 'admin') }
  let(:partner_role) { UserRole.find_or_create_by(name: 'partner') }
  let(:operator_role) { UserRole.find_or_create_by(name: 'operator') }
  let(:client_role) { UserRole.find_or_create_by(name: 'client') }

  # Создаем пользователей
  let(:admin_user) { create(:user, role: admin_role) }
  let(:partner1_user) { create(:user, role: partner_role) }
  let(:partner2_user) { create(:user, role: partner_role) }
  let(:operator1_user) { create(:user, role: operator_role) }
  let(:operator2_user) { create(:user, role: operator_role) }
  let(:client1_user) { create(:user, role: client_role) }
  let(:client2_user) { create(:user, role: client_role) }

  # Создаем профили
  let!(:admin) { create(:administrator, user: admin_user) }
  let!(:partner1) { create(:partner, user: partner1_user) }
  let!(:partner2) { create(:partner, user: partner2_user) }
  let!(:operator1) { create(:operator, user: operator1_user, partner: partner1) }
  let!(:operator2) { create(:operator, user: operator2_user, partner: partner2) }
  let!(:client1) { create(:client, user: client1_user) }
  let!(:client2) { create(:client, user: client2_user) }

  # Создаем сервисные точки
  let!(:partner1_point1) { create(:service_point, partner: partner1) }
  let!(:partner1_point2) { create(:service_point, partner: partner1) }
  let!(:partner2_point1) { create(:service_point, partner: partner2) }

  # Создаем привязки операторов
  let!(:operator1_assignment) { create(:operator_service_point, operator: operator1, service_point: partner1_point1) }
  let!(:operator2_assignment) { create(:operator_service_point, operator: operator2, service_point: partner2_point1) }

  # Создаем бронирования
  let!(:booking1) { create(:booking, client: client1, service_point: partner1_point1) }
  let!(:booking2) { create(:booking, client: client2, service_point: partner2_point1) }

  # Создаем отзывы
  let!(:review1) { create(:review, client: client1, service_point: partner1_point1) }
  let!(:review2) { create(:review, client: client2, service_point: partner2_point1) }

  describe 'Partner Data Isolation' do
    context 'when partner1 requests clients' do
      before { sign_in partner1_user }

      it 'returns only clients who booked at partner1 service points' do
        get '/api/v1/clients'
        
        expect(response).to have_http_status(:success)
        client_ids = JSON.parse(response.body).map { |c| c['id'] }
        
        expect(client_ids).to include(client1.id)
        expect(client_ids).not_to include(client2.id)
      end
    end

    context 'when partner1 requests bookings' do
      before { sign_in partner1_user }

      it 'returns only bookings at partner1 service points' do
        get '/api/v1/bookings'
        
        expect(response).to have_http_status(:success)
        booking_ids = JSON.parse(response.body).map { |b| b['id'] }
        
        expect(booking_ids).to include(booking1.id)
        expect(booking_ids).not_to include(booking2.id)
      end
    end

    context 'when partner1 requests reviews' do
      before { sign_in partner1_user }

      it 'returns only reviews about partner1 service points' do
        get '/api/v1/reviews'
        
        expect(response).to have_http_status(:success)
        review_ids = JSON.parse(response.body).map { |r| r['id'] }
        
        expect(review_ids).to include(review1.id)
        expect(review_ids).not_to include(review2.id)
      end
    end

    context 'when partner1 requests service points' do
      before { sign_in partner1_user }

      it 'returns only partner1 service points' do
        get '/api/v1/service_points'
        
        expect(response).to have_http_status(:success)
        point_ids = JSON.parse(response.body).map { |p| p['id'] }
        
        expect(point_ids).to include(partner1_point1.id, partner1_point2.id)
        expect(point_ids).not_to include(partner2_point1.id)
      end
    end

    context 'when partner1 requests operators' do
      before { sign_in partner1_user }

      it 'returns only partner1 operators' do
        get '/api/v1/operators'
        
        expect(response).to have_http_status(:success)
        operator_ids = JSON.parse(response.body).map { |o| o['id'] }
        
        expect(operator_ids).to include(operator1.id)
        expect(operator_ids).not_to include(operator2.id)
      end
    end
  end

  describe 'Operator Data Isolation' do
    context 'when operator1 requests bookings' do
      before { sign_in operator1_user }

      it 'returns only bookings at assigned service points' do
        get '/api/v1/bookings'
        
        expect(response).to have_http_status(:success)
        booking_ids = JSON.parse(response.body).map { |b| b['id'] }
        
        expect(booking_ids).to include(booking1.id)
        expect(booking_ids).not_to include(booking2.id)
      end
    end

    context 'when operator1 requests service points' do
      before { sign_in operator1_user }

      it 'returns only assigned service points' do
        get '/api/v1/service_points'
        
        expect(response).to have_http_status(:success)
        point_ids = JSON.parse(response.body).map { |p| p['id'] }
        
        expect(point_ids).to include(partner1_point1.id)
        expect(point_ids).not_to include(partner1_point2.id, partner2_point1.id)
      end
    end

    context 'when operator1 requests reviews' do
      before { sign_in operator1_user }

      it 'returns only reviews about assigned service points' do
        get '/api/v1/reviews'
        
        expect(response).to have_http_status(:success)
        review_ids = JSON.parse(response.body).map { |r| r['id'] }
        
        expect(review_ids).to include(review1.id)
        expect(review_ids).not_to include(review2.id)
      end
    end
  end

  describe 'Admin Access' do
    context 'when admin requests any resource' do
      before { sign_in admin_user }

      it 'returns all clients' do
        get '/api/v1/clients'
        
        expect(response).to have_http_status(:success)
        client_ids = JSON.parse(response.body).map { |c| c['id'] }
        
        expect(client_ids).to include(client1.id, client2.id)
      end

      it 'returns all bookings' do
        get '/api/v1/bookings'
        
        expect(response).to have_http_status(:success)
        booking_ids = JSON.parse(response.body).map { |b| b['id'] }
        
        expect(booking_ids).to include(booking1.id, booking2.id)
      end

      it 'returns all service points' do
        get '/api/v1/service_points'
        
        expect(response).to have_http_status(:success)
        point_ids = JSON.parse(response.body).map { |p| p['id'] }
        
        expect(point_ids).to include(partner1_point1.id, partner1_point2.id, partner2_point1.id)
      end
    end
  end

  describe 'Cross-Partner Access Prevention' do
    context 'when partner1 tries to access partner2 specific resource' do
      before { sign_in partner1_user }

      it 'denies access to partner2 service point' do
        get "/api/v1/service_points/#{partner2_point1.id}"
        
        expect(response).to have_http_status(:forbidden)
      end

      it 'denies access to partner2 booking' do
        get "/api/v1/bookings/#{booking2.id}"
        
        expect(response).to have_http_status(:forbidden)
      end

      it 'denies access to partner2 operator' do
        get "/api/v1/operators/#{operator2.id}"
        
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'Operator Cross-Assignment Prevention' do
    context 'when operator1 tries to access unassigned service point data' do
      before { sign_in operator1_user }

      it 'denies access to unassigned service point' do
        get "/api/v1/service_points/#{partner1_point2.id}"
        
        expect(response).to have_http_status(:forbidden)
      end

      it 'does not return bookings from unassigned service points' do
        # Создаем бронирование на неназначенной точке
        unassigned_booking = create(:booking, client: client1, service_point: partner1_point2)
        
        get '/api/v1/bookings'
        
        expect(response).to have_http_status(:success)
        booking_ids = JSON.parse(response.body).map { |b| b['id'] }
        
        expect(booking_ids).not_to include(unassigned_booking.id)
      end
    end
  end

  private

  def sign_in(user)
    # Имитируем аутентификацию через JWT токен
    token = JWT.encode({ user_id: user.id }, Rails.application.credentials.secret_key_base, 'HS256')
    @auth_headers = { 'Authorization' => "Bearer #{token}" }
  end

  def get(path, **options)
    super(path, headers: @auth_headers, **options)
  end
end 