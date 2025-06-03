require 'rails_helper'

RSpec.describe Api::V1::ServicePostsController, type: :request do
  describe 'GET /api/v1/service_points/:service_point_id/service_posts' do
    context 'без авторизации' do
      it 'возвращает список постов обслуживания' do
        # Создаем все объекты локально для теста
        partner_user = create(:user, :partner)
        partner = Partner.create!(
          user: partner_user,
          company_name: 'Test Company',
          contact_person: 'Test Person', 
          legal_address: 'Test Address',
          is_active: true
        )
        city = create(:city)
        service_point = create(:service_point, partner: partner, city: city)
        create_list(:service_post, 3, service_point: service_point)
        
        get "/api/v1/service_points/#{service_point.id}/service_posts"
        
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to be_an(Array)
        expect(JSON.parse(response.body).size).to eq(3)
      end
    end

    context 'с авторизацией админа' do
      it 'возвращает список постов обслуживания' do
        admin_user = create(:user, :admin)
        partner_user = create(:user, :partner)
        partner = Partner.create!(
          user: partner_user,
          company_name: 'Test Company',
          contact_person: 'Test Person',
          legal_address: 'Test Address', 
          is_active: true
        )
        city = create(:city)
        service_point = create(:service_point, partner: partner, city: city)
        
        admin_headers = auth_headers_for(admin_user)
        get "/api/v1/service_points/#{service_point.id}/service_posts", headers: admin_headers
        
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to be_an(Array)
      end
    end
  end

  describe 'GET /api/v1/service_points/:service_point_id/service_posts/:id' do
    context 'без авторизации' do
      it 'возвращает информацию о посте' do
        partner_user = create(:user, :partner)
        partner = Partner.create!(
          user: partner_user,
          company_name: 'Test Company',
          contact_person: 'Test Person',
          legal_address: 'Test Address',
          is_active: true
        )
        city = create(:city)
        service_point = create(:service_point, partner: partner, city: city)
        service_post = create(:service_post, service_point: service_point)
        
        get "/api/v1/service_points/#{service_point.id}/service_posts/#{service_post.id}"
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['id']).to eq(service_post.id)
        expect(json_response['post_number']).to eq(service_post.post_number)
        expect(json_response['name']).to eq(service_post.name)
      end
    end
  end

  describe 'POST /api/v1/service_points/:service_point_id/service_posts' do
    context 'с авторизацией админа' do
      it 'создает новый пост обслуживания' do
        admin_user = create(:user, :admin)
        partner_user = create(:user, :partner)
        partner = Partner.create!(
          user: partner_user,
          company_name: 'Test Company',
          contact_person: 'Test Person',
          legal_address: 'Test Address',
          is_active: true
        )
        city = create(:city)
        service_point = create(:service_point, partner: partner, city: city)
        
        valid_attributes = {
          service_post: {
            post_number: 5,
            name: 'Новый пост',
            slot_duration: 45,
            description: 'Описание нового поста'
          }
        }
        
        admin_headers = auth_headers_for(admin_user)
        
        expect {
          post "/api/v1/service_points/#{service_point.id}/service_posts", 
               params: valid_attributes, headers: admin_headers
        }.to change(ServicePost, :count).by(1)
        
        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response['name']).to eq('Новый пост')
        expect(json_response['slot_duration']).to eq(45)
      end
    end

    context 'без авторизации' do
      it 'возвращает ошибку авторизации' do
        partner_user = create(:user, :partner)
        partner = Partner.create!(
          user: partner_user,
          company_name: 'Test Company',
          contact_person: 'Test Person',
          legal_address: 'Test Address',
          is_active: true
        )
        city = create(:city)
        service_point = create(:service_point, partner: partner, city: city)
        
        valid_attributes = {
          service_post: {
            post_number: 5,
            name: 'Новый пост',
            slot_duration: 45,
            description: 'Описание нового поста'
          }
        }
        
        post "/api/v1/service_points/#{service_point.id}/service_posts", params: valid_attributes
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/service_points/:service_point_id/service_posts/:id' do
    context 'с авторизацией админа' do
      it 'обновляет пост обслуживания' do
        admin_user = create(:user, :admin)
        partner_user = create(:user, :partner)
        partner = Partner.create!(
          user: partner_user,
          company_name: 'Test Company',
          contact_person: 'Test Person',
          legal_address: 'Test Address',
          is_active: true
        )
        city = create(:city)
        service_point = create(:service_point, partner: partner, city: city)
        service_post = create(:service_post, service_point: service_point)
        
        update_attributes = {
          service_post: {
            name: 'Обновленный пост',
            slot_duration: 90,
            description: 'Обновленное описание'
          }
        }
        
        admin_headers = auth_headers_for(admin_user)
        
        put "/api/v1/service_points/#{service_point.id}/service_posts/#{service_post.id}", 
            params: update_attributes, headers: admin_headers
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['name']).to eq('Обновленный пост')
        expect(json_response['slot_duration']).to eq(90)
        
        service_post.reload
        expect(service_post.name).to eq('Обновленный пост')
      end
    end
  end

  describe 'DELETE /api/v1/service_points/:service_point_id/service_posts/:id' do
    context 'с авторизацией админа' do
      it 'удаляет пост обслуживания' do
        admin_user = create(:user, :admin)
        partner_user = create(:user, :partner)
        partner = Partner.create!(
          user: partner_user,
          company_name: 'Test Company',
          contact_person: 'Test Person',
          legal_address: 'Test Address',
          is_active: true
        )
        city = create(:city)
        service_point = create(:service_point, partner: partner, city: city)
        service_post = create(:service_post, service_point: service_point)
        
        admin_headers = auth_headers_for(admin_user)
        
        expect {
          delete "/api/v1/service_points/#{service_point.id}/service_posts/#{service_post.id}", 
                 headers: admin_headers
        }.to change(ServicePost, :count).by(-1)
        
        expect(response).to have_http_status(:no_content)
      end
    end
  end

  private

  def auth_headers_for(user)
    token = JWT.encode(
      { user_id: user.id, exp: 1.hour.from_now.to_i, token_type: 'access' },
      Rails.application.credentials.secret_key_base
    )
    { 'Authorization' => "Bearer #{token}" }
  end
end 