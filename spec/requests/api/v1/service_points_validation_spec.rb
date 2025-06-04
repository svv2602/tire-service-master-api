require 'rails_helper'

RSpec.describe 'API V1 ServicePoints Validation', type: :request do
  include RequestSpecHelper
  include ServicePointsTestHelper
  
  # Создаем роли для тестов
  let!(:partner_role) do
    UserRole.find_by(name: 'partner') || create(:user_role, name: 'partner', description: 'Partner role')
  end
  
  let(:partner_user) { create(:user, role_id: partner_role.id) }
  let(:partner) { create(:partner, user: partner_user) }
  let(:partner_headers) { generate_auth_headers(partner_user) }
  
  let(:city) { create(:city) }
  let(:service_point) { create(:service_point, partner: partner, city: city) }
  let(:service_category) { create(:service_category) }
  let(:service) { create(:service, category: service_category) }

  describe 'валидация service_posts_attributes' do
    context 'дубликат post_number в рамках одной сервисной точки' do
      let(:invalid_posts_params) do
        {
          service_point: {
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
                post_number: 1  # Дубликат номера поста
              }
            ]
          }
        }
      end
      
      it 'возвращает ошибку валидации для дубликата post_number' do
        patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
              params: invalid_posts_params.to_json,
              headers: partner_headers
        
        expect(response).to have_http_status(422)
        expect(json['errors']).to be_present
        expect(json['errors'].to_s).to include('post_number')
      end
    end
    
    context 'невалидные данные поста' do
      let(:invalid_post_data) do
        {
          service_point: {
            service_posts_attributes: [
              {
                name: '', # Пустое имя
                slot_duration: -10, # Отрицательная длительность
                is_active: true,
                post_number: nil # Отсутствует номер поста
              }
            ]
          }
        }
      end
      
      it 'возвращает ошибки валидации для полей поста' do
        patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
              params: invalid_post_data.to_json,
              headers: partner_headers
        
        expect(response).to have_http_status(422)
        expect(json['errors']).to be_present
      end
    end
  end
  
  describe 'валидация photos_attributes' do
    context 'несколько главных фотографий' do
      let(:test_file) { Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_logo.png'), 'image/png') }
      
      let(:multiple_main_photos) do
        {
          'service_point[photos_attributes][0][file]' => test_file,
          'service_point[photos_attributes][0][is_main]' => 'true',
          'service_point[photos_attributes][0][sort_order]' => '1',
          
          'service_point[photos_attributes][1][file]' => test_file,
          'service_point[photos_attributes][1][is_main]' => 'true', # Дубликат главной фотографии
          'service_point[photos_attributes][1][sort_order]' => '2'
        }
      end
      
      it 'возвращает ошибку для множественных главных фотографий' do
        patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
              params: multiple_main_photos,
              headers: partner_headers
        
        expect(response).to have_http_status(422)
        expect(json['errors']).to be_present
        expect(json['errors'].to_s).to include('main')
      end
    end
    
    context 'фотография без файла' do
      let(:photo_without_file) do
        {
          service_point: {
            photos_attributes: [
              {
                description: 'Фото без файла',
                is_main: true,
                sort_order: 1
                # Отсутствует файл
              }
            ]
          }
        }
      end
      
      it 'возвращает ошибку для фотографии без файла при создании' do
        patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
              params: photo_without_file.to_json,
              headers: partner_headers
        
        expect(response).to have_http_status(422)
        expect(json['errors']).to be_present
        expect(json['errors'].to_s).to include('file')
      end
    end
  end
  
  describe 'валидация services_attributes' do
    context 'дубликат услуги в рамках одной сервисной точки' do
      let(:duplicate_service_params) do
        {
          service_point: {
            services_attributes: [
              {
                service_id: service.id,
                price: 100.0,
                duration: 30,
                is_available: true
              },
              {
                service_id: service.id, # Дубликат услуги
                price: 150.0,
                duration: 45,
                is_available: true
              }
            ]
          }
        }
      end
      
      it 'возвращает ошибку для дубликата услуги' do
        patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
              params: duplicate_service_params.to_json,
              headers: partner_headers
        
        expect(response).to have_http_status(422)
        expect(json['errors']).to be_present
        expect(json['errors'].to_s).to include('service')
      end
    end
    
    context 'невалидные данные услуги' do
      let(:invalid_service_data) do
        {
          service_point: {
            services_attributes: [
              {
                service_id: nil, # Отсутствует ID услуги
                price: -50.0, # Отрицательная цена
                duration: 0, # Нулевая длительность
                is_available: true
              }
            ]
          }
        }
      end
      
      it 'возвращает ошибки валидации для полей услуги' do
        patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
              params: invalid_service_data.to_json,
              headers: partner_headers
        
        expect(response).to have_http_status(422)
        expect(json['errors']).to be_present
      end
    end
  end
  
  describe 'валидация working_hours' do
    context 'невалидное время' do
      let(:invalid_schedule) do
        {
          service_point: {
            working_hours: {
              monday: { 
                start: '25:00', # Невалидное время начала
                end: '18:00', 
                is_working_day: true 
              },
              tuesday: { 
                start: '09:00', 
                end: '08:00', # Время окончания раньше времени начала
                is_working_day: true 
              }
            }
          }
        }
      end
      
      it 'возвращает ошибку для невалидного расписания' do
        patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
              params: invalid_schedule.to_json,
              headers: partner_headers
        
        expect(response).to have_http_status(422)
        expect(json['errors']).to be_present
        expect(json['errors'].to_s).to include('working_hours')
      end
    end
  end
  
  describe 'комплексная валидация при создании' do
    context 'создание с множественными ошибками валидации' do
      let(:test_file) { Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_logo.png'), 'image/png') }
      
      let(:complex_invalid_params) do
        {
          'service_point[name]' => '', # Пустое имя
          'service_point[address]' => '',  # Пустой адрес
          'service_point[city_id]' => '',  # Пустой город
          'service_point[partner_id]' => partner.id.to_s,
          'service_point[contact_phone]' => 'invalid-phone', # Невалидный телефон
          'service_point[is_active]' => 'true',
          'service_point[work_status]' => 'invalid_status', # Невалидный статус
          
          # Посты с ошибками
          'service_point[service_posts_attributes][0][name]' => '',
          'service_point[service_posts_attributes][0][slot_duration]' => '-10',
          'service_point[service_posts_attributes][0][is_active]' => 'true',
          'service_point[service_posts_attributes][0][post_number]' => '',
          
          'service_point[service_posts_attributes][1][name]' => 'Пост 2',
          'service_point[service_posts_attributes][1][slot_duration]' => '30',
          'service_point[service_posts_attributes][1][is_active]' => 'true',
          'service_point[service_posts_attributes][1][post_number]' => '', # Дубликат пустого номера
          
          # Услуги с ошибками
          'service_point[services_attributes][0][service_id]' => '',
          'service_point[services_attributes][0][price]' => '-100',
          'service_point[services_attributes][0][duration]' => '0',
          'service_point[services_attributes][0][is_available]' => 'true',
          
          # Фотографии с ошибками
          'service_point[photos_attributes][0][file]' => test_file,
          'service_point[photos_attributes][0][is_main]' => 'true',
          'service_point[photos_attributes][0][sort_order]' => 'invalid',
          
          'service_point[photos_attributes][1][file]' => test_file,
          'service_point[photos_attributes][1][is_main]' => 'true', # Дубликат главной фотографии
          'service_point[photos_attributes][1][sort_order]' => '2'
        }
      end
      
      it 'возвращает все ошибки валидации сразу' do
        post "/api/v1/partners/#{partner.id}/service_points",
             params: complex_invalid_params,
             headers: partner_headers
        
        expect(response).to have_http_status(422)
        expect(json['errors']).to be_present
        
        # Проверяем что ошибки содержат информацию о различных полях
        errors_string = json['errors'].to_s
        expect(errors_string).to include('name')
        expect(errors_string).to include('address') 
        # Другие специфические проверки зависят от реализации валидации
      end
    end
  end
  
  describe 'проверка ролей и авторизации' do
    context 'неавторизованный пользователь' do
      it 'возвращает ошибку авторизации при создании' do
        post "/api/v1/partners/#{partner.id}/service_points",
             params: { service_point: { name: 'Test Point' } }.to_json
        
        expect(response).to have_http_status(401)
      end
      
      it 'возвращает ошибку авторизации при обновлении' do
        patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
              params: { service_point: { name: 'Updated' } }.to_json
        
        expect(response).to have_http_status(401)
      end
    end
    
    context 'пользователь без прав на сервисную точку' do
      let(:other_partner_user) { create(:user, role_id: partner_role.id) }
      let(:other_partner) { create(:partner, user: other_partner_user) }
      let(:other_partner_headers) { generate_auth_headers(other_partner_user) }
      
      it 'возвращает ошибку доступа при обновлении чужой сервисной точки' do
        patch "/api/v1/partners/#{other_partner.id}/service_points/#{service_point.id}",
              params: { service_point: { name: 'Hacked' } }.to_json,
              headers: other_partner_headers
        
        expect(response).to have_http_status(404) # Или 403, в зависимости от реализации
      end
    end
  end
  
  describe 'лимиты и ограничения' do
    context 'превышение лимита фотографий' do
      let(:too_many_photos) do
        params = {
          'service_point[name]' => 'Точка с множеством фото',
          'service_point[address]' => service_point.address,
          'service_point[city_id]' => city.id.to_s,
          'service_point[partner_id]' => partner.id.to_s,
          'service_point[contact_phone]' => service_point.contact_phone,
          'service_point[is_active]' => 'true',
          'service_point[work_status]' => 'working'
        }
        
        # Добавляем 15 фотографий (если лимит 10)
        15.times do |i|
          test_file = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_logo.png'), 'image/png')
          params["service_point[photos_attributes][#{i}][file]"] = test_file
          params["service_point[photos_attributes][#{i}][description]"] = "Фото #{i + 1}"
          params["service_point[photos_attributes][#{i}][is_main]"] = (i == 0).to_s
          params["service_point[photos_attributes][#{i}][sort_order]"] = (i + 1).to_s
        end
        
        params
      end
      
      it 'возвращает ошибку при превышении лимита фотографий' do
        patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
              params: too_many_photos,
              headers: partner_headers
        
        # Если есть лимит на количество фотографий
        expect(response).to have_http_status(422)
        expect(json['errors']).to be_present
        expect(json['errors'].to_s).to include('photos')
      end
    end
  end
end 