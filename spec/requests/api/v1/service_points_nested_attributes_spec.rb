require 'rails_helper'

RSpec.describe 'API V1 ServicePoints Nested Attributes', type: :request do
  include RequestSpecHelper
  include ServicePointsTestHelper
  
  # Создаем роли для тестов
  let!(:partner_role) do
    UserRole.find_by(name: 'partner') || create(:user_role, name: 'partner', description: 'Partner role')
  end
  
  let!(:admin_role) do
    UserRole.find_by(name: 'admin') || create(:user_role, name: 'admin', description: 'Admin role')
  end
  
  let(:partner_user) { create(:user, role_id: partner_role.id) }
  let(:partner) { create(:partner, user: partner_user) }
  let(:partner_headers) { generate_auth_headers(partner_user) }
  
  let(:admin_user) { create(:user, role_id: admin_role.id) }
  let(:admin_headers) { generate_auth_headers(admin_user) }
  
  let(:city) { create(:city) }
  let(:service_point) { create(:service_point, partner: partner, city: city) }
  let(:service_category) { create(:service_category) }
  let(:service) { create(:service, category: service_category) }

  describe 'PATCH /api/v1/partners/:partner_id/service_points/:id with nested attributes' do
    context 'обновление с service_posts_attributes' do
      let(:existing_post) { create(:service_post, service_point: service_point, name: 'Существующий пост', post_number: 1) }
      
      let(:update_params) do
        {
          service_point: {
            name: 'Обновленная точка',
            service_posts_attributes: [
              {
                id: existing_post.id,
                name: 'Обновленный пост',
                slot_duration: 45,
                is_active: true,
                post_number: 1,
                _destroy: false
              },
              {
                name: 'Новый пост',
                slot_duration: 30,
                is_active: true,
                post_number: 2,
                _destroy: false
              }
            ]
          }
        }
      end
      
      before do
        existing_post # Создаем пост перед тестом
      end
      
      context 'как партнер' do
        it 'обновляет существующие посты и создает новые' do
          expect {
            patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
                  params: update_params.to_json,
                  headers: partner_headers
          }.to change(ServicePost, :count).by(1)
          
          expect(response).to have_http_status(200)
          
          # Проверяем обновление существующего поста
          existing_post.reload
          expect(existing_post.name).to eq('Обновленный пост')
          expect(existing_post.slot_duration).to eq(45)
          
          # Проверяем создание нового поста
          new_post = service_point.service_posts.find_by(post_number: 2)
          expect(new_post).to be_present
          expect(new_post.name).to eq('Новый пост')
          expect(new_post.slot_duration).to eq(30)
        end
        
        it 'возвращает обновленные данные сервисной точки' do
          patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
                params: update_params.to_json,
                headers: partner_headers
          
          expect(json['name']).to eq('Обновленная точка')
          expect(json['service_posts']).to be_present
          expect(json['service_posts'].size).to eq(2)
        end
      end
      
      context 'удаление постов через _destroy' do
        let(:delete_params) do
          {
            service_point: {
              service_posts_attributes: [
                {
                  id: existing_post.id,
                  _destroy: true
                }
              ]
            }
          }
        end
        
        it 'удаляет посты с _destroy: true' do
          expect {
            patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
                  params: delete_params.to_json,
                  headers: partner_headers
          }.to change(ServicePost, :count).by(-1)
          
          expect(response).to have_http_status(200)
          expect(ServicePost.find_by(id: existing_post.id)).to be_nil
        end
      end
    end
    
    context 'обновление с services_attributes' do
      let(:existing_service) { create(:service_point_service, service_point: service_point, service: service, price: 100.0) }
      
      let(:update_params) do
        {
          service_point: {
            services_attributes: [
              {
                id: existing_service.id,
                service_id: service.id,
                price: 150.0,
                duration: 60,
                is_available: true,
                _destroy: false
              },
              {
                service_id: service.id,
                price: 200.0,
                duration: 90,
                is_available: true,
                _destroy: false
              }
            ]
          }
        }
      end
      
      before do
        existing_service # Создаем услугу перед тестом
      end
      
      it 'обновляет существующие услуги и создает новые' do
        expect {
          patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
                params: update_params.to_json,
                headers: partner_headers
        }.to change(ServicePointService, :count).by(1)
        
        expect(response).to have_http_status(200)
        
        # Проверяем обновление существующей услуги
        existing_service.reload
        expect(existing_service.price).to eq(150.0)
        expect(existing_service.duration).to eq(60)
        
        # Проверяем создание новой услуги
        new_service = service_point.service_point_services.where(price: 200.0).first
        expect(new_service).to be_present
        expect(new_service.duration).to eq(90)
      end
    end
    
    context 'обновление с working_hours' do
      let(:update_params) do
        {
          service_point: {
            working_hours: {
              monday: { start: '08:00', end: '20:00', is_working_day: true },
              tuesday: { start: '08:00', end: '20:00', is_working_day: true },
              wednesday: { start: '08:00', end: '20:00', is_working_day: true },
              thursday: { start: '08:00', end: '20:00', is_working_day: true },
              friday: { start: '08:00', end: '20:00', is_working_day: true },
              saturday: { start: '10:00', end: '18:00', is_working_day: true },
              sunday: { start: '10:00', end: '18:00', is_working_day: false }
            }
          }
        }
      end
      
      it 'обновляет расписание работы' do
        patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
              params: update_params.to_json,
              headers: partner_headers
        
        expect(response).to have_http_status(200)
        
        service_point.reload
        expect(service_point.working_hours['monday']['start']).to eq('08:00')
        expect(service_point.working_hours['monday']['end']).to eq('20:00')
        expect(service_point.working_hours['monday']['is_working_day']).to be true
        expect(service_point.working_hours['sunday']['is_working_day']).to be false
      end
    end
  end
  
  describe 'POST /api/v1/partners/:partner_id/service_points with nested attributes' do
    let(:create_params) do
      {
        service_point: {
          name: 'Новая точка обслуживания',
          address: 'ул. Тестовая, 123',
          city_id: city.id,
          partner_id: partner.id,
          contact_phone: '+380 50 123 45 67',
          is_active: true,
          work_status: 'working',
          working_hours: {
            monday: { start: '09:00', end: '18:00', is_working_day: true },
            tuesday: { start: '09:00', end: '18:00', is_working_day: true },
            wednesday: { start: '09:00', end: '18:00', is_working_day: true },
            thursday: { start: '09:00', end: '18:00', is_working_day: true },
            friday: { start: '09:00', end: '18:00', is_working_day: true },
            saturday: { start: '10:00', end: '16:00', is_working_day: true },
            sunday: { start: '10:00', end: '16:00', is_working_day: false }
          },
          service_posts_attributes: [
            {
              name: 'Пост 1',
              slot_duration: 30,
              is_active: true,
              post_number: 1
            },
            {
              name: 'Пост 2',
              slot_duration: 45,
              is_active: true,
              post_number: 2
            }
          ],
          services_attributes: [
            {
              service_id: service.id,
              price: 250.0,
              duration: 60,
              is_available: true
            }
          ]
        }
      }
    end
    
    context 'создание с полными nested attributes' do
      it 'создает сервисную точку со всеми связанными данными' do
        expect {
          post "/api/v1/partners/#{partner.id}/service_points",
               params: create_params.to_json,
               headers: partner_headers
        }.to change(ServicePoint, :count).by(1)
         .and change(ServicePost, :count).by(2)
         .and change(ServicePointService, :count).by(1)
        
        expect(response).to have_http_status(200)
        
        created_point = ServicePoint.last
        expect(created_point.name).to eq('Новая точка обслуживания')
        expect(created_point.working_hours['monday']['start']).to eq('09:00')
        expect(created_point.service_posts.count).to eq(2)
        expect(created_point.service_point_services.count).to eq(1)
      end
    end
    
    context 'с невалидными данными' do
      let(:invalid_params) do
        {
          service_point: {
            name: '', # Пустое имя
            service_posts_attributes: [
              {
                name: 'Пост без номера',
                slot_duration: 30,
                is_active: true
                # Отсутствует post_number
              }
            ]
          }
        }
      end
      
      it 'возвращает ошибки валидации' do
        post "/api/v1/partners/#{partner.id}/service_points",
             params: invalid_params.to_json,
             headers: partner_headers
        
        expect(response).to have_http_status(422)
        expect(json['errors']).to be_present
      end
    end
  end
end 