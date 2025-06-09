require 'rails_helper'

RSpec.describe "Api::V1::ServicePoints Client Endpoints", type: :request do
  let!(:region) { create(:region, name: 'Киевская область') }
  let!(:city_kyiv) { create(:city, name: 'Киев', region: region) }
  let!(:city_lviv) { create(:city, name: 'Львов', region: region) }
  let!(:partner) { create(:partner) }
  
  # Активные рабочие точки
  let!(:active_point_kyiv) do
    create(:service_point, 
           name: 'ШиноСервис Центр',
           address: 'ул. Крещатик, 1',
           city: city_kyiv,
           partner: partner,
           is_active: true,
           work_status: 'working',
           average_rating: 4.5)
  end
  
  let!(:active_point_kyiv_2) do
    create(:service_point,
           name: 'АвтоШина Экспресс', 
           address: 'пр. Победы, 15',
           city: city_kyiv,
           partner: partner,
           is_active: true,
           work_status: 'working',
           average_rating: 4.2)
  end
  
  let!(:active_point_lviv) do
    create(:service_point,
           name: 'ШинМастер Львов',
           city: city_lviv,
           partner: partner, 
           is_active: true,
           work_status: 'working',
           average_rating: 4.8)
  end
  
  # Неактивные точки (не должны показываться)
  let!(:inactive_point) do
    create(:service_point,
           name: 'Закрытый сервис',
           city: city_kyiv,
           partner: partner,
           is_active: false,
           work_status: 'suspended')
  end
  
  let!(:maintenance_point) do 
    create(:service_point,
           name: 'Сервис на обслуживании',
           city: city_kyiv,
           partner: partner,
           is_active: true,
           work_status: 'maintenance')
  end

  describe "GET /api/v1/service_points/search" do
    context "поиск по городу" do
      it "возвращает только активные точки из указанного города" do
        get "/api/v1/service_points/search", params: { city: 'Киев' }
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['data'].size).to eq(2)
        expect(json['total']).to eq(2)
        expect(json['city_found']).to be true
        
        # Проверяем, что возвращаются только киевские активные точки
        names = json['data'].map { |p| p['name'] }
        expect(names).to include('ШиноСервис Центр', 'АвтоШина Экспресс')
        expect(names).not_to include('Закрытый сервис', 'Сервис на обслуживании')
        
        # Проверяем структуру ответа
        point = json['data'].first
        expect(point).to include(
          'id', 'name', 'address', 'city', 'partner',
          'contact_phone', 'average_rating', 'reviews_count',
          'posts_count', 'can_accept_bookings', 'work_status'
        )
        expect(point['can_accept_bookings']).to be true
      end
      
      it "возвращает точки из Львова" do
        get "/api/v1/service_points/search", params: { city: 'Львов' }
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['data'].size).to eq(1)
        expect(json['data'].first['name']).to eq('ШинМастер Львов')
      end
      
      it "возвращает пустой результат для несуществующего города" do
        get "/api/v1/service_points/search", params: { city: 'Несуществующий' }
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['data']).to be_empty
        expect(json['total']).to eq(0)
        expect(json['city_found']).to be false
      end
    end
    
    context "поиск по названию точки" do
      it "находит точки по частичному совпадению названия" do
        get "/api/v1/service_points/search", params: { 
          city: 'Киев',
          query: 'Шино'
        }
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['data'].size).to eq(1)
        expect(json['data'].first['name']).to eq('ШиноСервис Центр')
      end
      
      it "находит точки по адресу" do
        get "/api/v1/service_points/search", params: {
          city: 'Киев',
          query: 'Крещатик'
        }
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['data'].size).to eq(1)
        expect(json['data'].first['name']).to eq('ШиноСервис Центр')
      end
    end
    
    context "сортировка по рейтингу" do
      it "сортирует точки по убыванию рейтинга" do
        get "/api/v1/service_points/search", params: { city: 'Киев' }
        
        json = JSON.parse(response.body)
        ratings = json['data'].map { |p| p['average_rating'] }
        
        expect(ratings).to eq([4.5, 4.2]) # по убыванию
      end
    end
    
    context "поиск без параметров" do
      it "возвращает все активные точки" do
        get "/api/v1/service_points/search"
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['data'].size).to eq(3) # только активные working
        expect(json['total']).to eq(3)
      end
    end
  end

  describe "GET /api/v1/service_points/:id/client_details" do
    context "для активной точки" do
      let!(:amenity) { create(:amenity, name: 'Wi-Fi', icon: 'wifi') }
      let!(:service_category) { create(:service_category, name: 'Шиномонтаж') }
      let!(:service) { create(:service, name: 'Замена колеса', service_category: service_category, is_active: true) }
      let!(:client) { create(:client) }
      let!(:review) { create(:review, service_point: active_point_kyiv, client: client, rating: 5, comment: 'Отличный сервис!') }
      
      before do
        active_point_kyiv.amenities << amenity
        active_point_kyiv.services << service
        create(:service_post, service_point: active_point_kyiv, name: 'Пост 1', is_active: true)
        create(:service_post, service_point: active_point_kyiv, name: 'Пост 2', is_active: true)
      end
      
      it "возвращает полную информацию о точке" do
        get "/api/v1/service_points/#{active_point_kyiv.id}/client_details"
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json).to include(
          'id', 'name', 'description', 'address', 'city', 'partner',
          'contact_phone', 'latitude', 'longitude', 'average_rating',
          'reviews_count', 'total_clients_served', 'posts_count',
          'can_accept_bookings', 'work_status', 'is_working_today',
          'amenities', 'photos', 'services_available', 'recent_reviews'
        )
        
        expect(json['can_accept_bookings']).to be true
        expect(json['posts_count']).to eq(2)
        expect(json['amenities'].first['name']).to eq('Wi-Fi')
        expect(json['services_available'].first['name']).to eq('Замена колеса')
        expect(json['recent_reviews'].first['comment']).to eq('Отличный сервис!')
      end
    end
    
    context "для неактивной точки" do
      it "возвращает ошибку 403" do
        get "/api/v1/service_points/#{inactive_point.id}/client_details"
        
        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        
        expect(json['error']).to include('недоступна для записи')
        expect(json['reason']).to be_present
      end
    end
    
    context "для точки на обслуживании" do
      it "возвращает ошибку 403" do
        get "/api/v1/service_points/#{maintenance_point.id}/client_details"
        
        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        
        expect(json['error']).to include('недоступна для записи')
      end
    end
    
    context "для несуществующей точки" do
      it "возвращает ошибку 404" do
        get "/api/v1/service_points/99999/client_details"
        
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end 