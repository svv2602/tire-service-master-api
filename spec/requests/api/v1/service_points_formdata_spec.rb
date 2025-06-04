require 'rails_helper'

RSpec.describe 'API V1 ServicePoints FormData Upload', type: :request do
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
  
  # Путь к тестовому файлу
  let(:test_image_path) { Rails.root.join('spec/fixtures/files/test_logo.png') }
  let(:test_file) { Rack::Test::UploadedFile.new(test_image_path, 'image/png') }

  describe 'PATCH /api/v1/partners/:partner_id/service_points/:id с FormData' do
    context 'загрузка фотографий через FormData' do
      let(:form_data) do
        {
          'service_point[name]' => 'Обновленная точка с фото',
          'service_point[description]' => 'Обновленное описание',
          'service_point[address]' => service_point.address,
          'service_point[city_id]' => city.id.to_s,
          'service_point[partner_id]' => partner.id.to_s,
          'service_point[contact_phone]' => service_point.contact_phone,
          'service_point[is_active]' => 'true',
          'service_point[work_status]' => 'working',
          
          # Фотографии
          'service_point[photos_attributes][0][file]' => test_file,
          'service_point[photos_attributes][0][description]' => 'Тестовая фотография',
          'service_point[photos_attributes][0][is_main]' => 'true',
          'service_point[photos_attributes][0][sort_order]' => '1',
          
          'service_point[photos_attributes][1][file]' => test_file,
          'service_point[photos_attributes][1][description]' => 'Вторая фотография',
          'service_point[photos_attributes][1][is_main]' => 'false',
          'service_point[photos_attributes][1][sort_order]' => '2'
        }
      end
      
      it 'обновляет сервисную точку и загружает фотографии' do
        expect {
          patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
                params: form_data,
                headers: partner_headers
        }.to change(ServicePointPhoto, :count).by(2)
        
        expect(response).to have_http_status(200)
        
        # Проверяем обновление данных
        service_point.reload
        expect(service_point.name).to eq('Обновленная точка с фото')
        expect(service_point.description).to eq('Обновленное описание')
        
        # Проверяем фотографии
        photos = service_point.photos.order(:sort_order)
        expect(photos.count).to eq(2)
        
        main_photo = photos.first
        expect(main_photo.description).to eq('Тестовая фотография')
        expect(main_photo.is_main).to be true
        expect(main_photo.sort_order).to eq(1)
        expect(main_photo.file).to be_attached
        
        second_photo = photos.second
        expect(second_photo.description).to eq('Вторая фотография')
        expect(second_photo.is_main).to be false
        expect(second_photo.sort_order).to eq(2)
        expect(second_photo.file).to be_attached
      end
      
      it 'возвращает данные с загруженными фотографиями' do
        patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
              params: form_data,
              headers: partner_headers
        
        expect(json['name']).to eq('Обновленная точка с фото')
        expect(json['photos']).to be_present
        expect(json['photos'].size).to eq(2)
        
        # Проверяем URL фотографий
        photo_urls = json['photos'].map { |p| p['url'] }
        expect(photo_urls).to all(be_present)
        expect(photo_urls).to all(include('localhost:8000'))
      end
    end
    
    context 'смешанная загрузка: существующие фотографии + новые файлы' do
      let(:existing_photo) { create(:service_point_photo, service_point: service_point, description: 'Существующая фото') }
      
      let(:mixed_form_data) do
        {
          'service_point[name]' => 'Точка со смешанными фото',
          'service_point[address]' => service_point.address,
          'service_point[city_id]' => city.id.to_s,
          'service_point[partner_id]' => partner.id.to_s,
          'service_point[contact_phone]' => service_point.contact_phone,
          'service_point[is_active]' => 'true',
          'service_point[work_status]' => 'working',
          
          # Существующая фотография (обновление метаданных)
          'service_point[photos_attributes][0][id]' => existing_photo.id.to_s,
          'service_point[photos_attributes][0][description]' => 'Обновленное описание существующей фото',
          'service_point[photos_attributes][0][is_main]' => 'true',
          'service_point[photos_attributes][0][sort_order]' => '1',
          'service_point[photos_attributes][0][_destroy]' => 'false',
          
          # Новая фотография (файл)
          'service_point[photos_attributes][1][file]' => test_file,
          'service_point[photos_attributes][1][description]' => 'Новая фотография',
          'service_point[photos_attributes][1][is_main]' => 'false',
          'service_point[photos_attributes][1][sort_order]' => '2'
        }
      end
      
      before do
        existing_photo # Создаем существующую фотографию
      end
      
      it 'обновляет существующие фотографии и добавляет новые' do
        expect {
          patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
                params: mixed_form_data,
                headers: partner_headers
        }.to change(ServicePointPhoto, :count).by(1)
        
        expect(response).to have_http_status(200)
        
        # Проверяем обновление существующей фотографии
        existing_photo.reload
        expect(existing_photo.description).to eq('Обновленное описание существующей фото')
        expect(existing_photo.is_main).to be true
        
        # Проверяем новую фотографию
        new_photo = service_point.photos.where(description: 'Новая фотография').first
        expect(new_photo).to be_present
        expect(new_photo.file).to be_attached
      end
    end
    
    context 'с постами обслуживания в FormData' do
      let(:existing_post) { create(:service_post, service_point: service_point, name: 'Существующий пост') }
      
      let(:posts_form_data) do
        {
          'service_point[name]' => 'Точка с постами',
          'service_point[address]' => service_point.address,
          'service_point[city_id]' => city.id.to_s,
          'service_point[partner_id]' => partner.id.to_s,
          'service_point[contact_phone]' => service_point.contact_phone,
          'service_point[is_active]' => 'true',
          'service_point[work_status]' => 'working',
          
          # Обновление существующего поста
          'service_point[service_posts_attributes][0][id]' => existing_post.id.to_s,
          'service_point[service_posts_attributes][0][name]' => 'Обновленный пост',
          'service_point[service_posts_attributes][0][description]' => 'Новое описание',
          'service_point[service_posts_attributes][0][slot_duration]' => '45',
          'service_point[service_posts_attributes][0][is_active]' => 'true',
          'service_point[service_posts_attributes][0][post_number]' => '1',
          'service_point[service_posts_attributes][0][_destroy]' => 'false',
          
          # Новый пост
          'service_point[service_posts_attributes][1][name]' => 'Новый пост через FormData',
          'service_point[service_posts_attributes][1][description]' => 'Описание нового поста',
          'service_point[service_posts_attributes][1][slot_duration]' => '30',
          'service_point[service_posts_attributes][1][is_active]' => 'true',
          'service_point[service_posts_attributes][1][post_number]' => '2',
          'service_point[service_posts_attributes][1][_destroy]' => 'false'
        }
      end
      
      before do
        existing_post # Создаем существующий пост
      end
      
      it 'обрабатывает посты через FormData' do
        expect {
          patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
                params: posts_form_data,
                headers: partner_headers
        }.to change(ServicePost, :count).by(1)
        
        expect(response).to have_http_status(200)
        
        # Проверяем обновление существующего поста
        existing_post.reload
        expect(existing_post.name).to eq('Обновленный пост')
        expect(existing_post.slot_duration).to eq(45)
        
        # Проверяем новый пост
        new_post = service_point.service_posts.find_by(post_number: 2)
        expect(new_post).to be_present
        expect(new_post.name).to eq('Новый пост через FormData')
        expect(new_post.slot_duration).to eq(30)
      end
    end
    
    context 'с услугами в FormData' do
      let(:existing_service) { create(:service_point_service, service_point: service_point, service: service, price: 100.0) }
      
      let(:services_form_data) do
        {
          'service_point[name]' => 'Точка с услугами',
          'service_point[address]' => service_point.address,
          'service_point[city_id]' => city.id.to_s,
          'service_point[partner_id]' => partner.id.to_s,
          'service_point[contact_phone]' => service_point.contact_phone,
          'service_point[is_active]' => 'true',
          'service_point[work_status]' => 'working',
          
          # Обновление существующей услуги
          'service_point[services_attributes][0][id]' => existing_service.id.to_s,
          'service_point[services_attributes][0][service_id]' => service.id.to_s,
          'service_point[services_attributes][0][price]' => '150.0',
          'service_point[services_attributes][0][duration]' => '60',
          'service_point[services_attributes][0][is_available]' => 'true',
          'service_point[services_attributes][0][_destroy]' => 'false',
          
          # Новая услуга
          'service_point[services_attributes][1][service_id]' => service.id.to_s,
          'service_point[services_attributes][1][price]' => '200.0',
          'service_point[services_attributes][1][duration]' => '90',
          'service_point[services_attributes][1][is_available]' => 'true',
          'service_point[services_attributes][1][_destroy]' => 'false'
        }
      end
      
      before do
        existing_service # Создаем существующую услугу
      end
      
      it 'обрабатывает услуги через FormData' do
        expect {
          patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
                params: services_form_data,
                headers: partner_headers
        }.to change(ServicePointService, :count).by(1)
        
        expect(response).to have_http_status(200)
        
        # Проверяем обновление существующей услуги
        existing_service.reload
        expect(existing_service.price).to eq(150.0)
        expect(existing_service.duration).to eq(60)
        
        # Проверяем новую услугу
        new_service = service_point.service_point_services.where(price: 200.0).first
        expect(new_service).to be_present
        expect(new_service.duration).to eq(90)
      end
    end
    
    context 'с расписанием работы в FormData' do
      let(:schedule_form_data) do
        {
          'service_point[name]' => 'Точка с расписанием',
          'service_point[address]' => service_point.address,
          'service_point[city_id]' => city.id.to_s,
          'service_point[partner_id]' => partner.id.to_s,
          'service_point[contact_phone]' => service_point.contact_phone,
          'service_point[is_active]' => 'true',
          'service_point[work_status]' => 'working',
          
          # Расписание работы
          'service_point[working_hours][monday][start]' => '08:00',
          'service_point[working_hours][monday][end]' => '20:00',
          'service_point[working_hours][monday][is_working_day]' => 'true',
          
          'service_point[working_hours][tuesday][start]' => '08:00',
          'service_point[working_hours][tuesday][end]' => '20:00',
          'service_point[working_hours][tuesday][is_working_day]' => 'true',
          
          'service_point[working_hours][sunday][start]' => '10:00',
          'service_point[working_hours][sunday][end]' => '18:00',
          'service_point[working_hours][sunday][is_working_day]' => 'false'
        }
      end
      
      it 'обрабатывает расписание работы через FormData' do
        patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
              params: schedule_form_data,
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
  
  describe 'POST /api/v1/partners/:partner_id/service_points с FormData' do
    let(:create_form_data) do
      {
        'service_point[name]' => 'Новая точка через FormData',
        'service_point[description]' => 'Описание новой точки',
        'service_point[address]' => 'ул. FormData, 123',
        'service_point[city_id]' => city.id.to_s,
        'service_point[partner_id]' => partner.id.to_s,
        'service_point[contact_phone]' => '+380 50 123 45 67',
        'service_point[is_active]' => 'true',
        'service_point[work_status]' => 'working',
        
        # Фотографии
        'service_point[photos_attributes][0][file]' => test_file,
        'service_point[photos_attributes][0][description]' => 'Главная фотография',
        'service_point[photos_attributes][0][is_main]' => 'true',
        'service_point[photos_attributes][0][sort_order]' => '1',
        
        # Посты
        'service_point[service_posts_attributes][0][name]' => 'Пост 1',
        'service_point[service_posts_attributes][0][slot_duration]' => '30',
        'service_point[service_posts_attributes][0][is_active]' => 'true',
        'service_point[service_posts_attributes][0][post_number]' => '1',
        
        # Услуги  
        'service_point[services_attributes][0][service_id]' => service.id.to_s,
        'service_point[services_attributes][0][price]' => '300.0',
        'service_point[services_attributes][0][duration]' => '60',
        'service_point[services_attributes][0][is_available]' => 'true'
      }
    end
    
    it 'создает сервисную точку с файлами и nested attributes через FormData' do
      expect {
        post "/api/v1/partners/#{partner.id}/service_points",
             params: create_form_data,
             headers: partner_headers
      }.to change(ServicePoint, :count).by(1)
       .and change(ServicePointPhoto, :count).by(1)
       .and change(ServicePost, :count).by(1)
       .and change(ServicePointService, :count).by(1)
      
      expect(response).to have_http_status(200)
      
      created_point = ServicePoint.last
      expect(created_point.name).to eq('Новая точка через FormData')
      expect(created_point.photos.count).to eq(1)
      expect(created_point.service_posts.count).to eq(1)
      expect(created_point.service_point_services.count).to eq(1)
      
      # Проверяем что файл прикреплен
      expect(created_point.photos.first.file).to be_attached
    end
  end
end 