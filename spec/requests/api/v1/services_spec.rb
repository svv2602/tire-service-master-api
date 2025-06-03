require 'rails_helper'

RSpec.describe "Api::V1::Services", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user, :client) }
  let(:admin_headers) { { 'Authorization' => "Bearer #{generate_token(admin)}" } }
  let(:user_headers) { { 'Authorization' => "Bearer #{generate_token(user)}" } }
  
  let(:category) { create(:service_category) }
  let(:other_category) { create(:service_category) }
  
  describe "GET /api/v1/service_categories/:service_category_id/services" do
    let!(:category_services) { create_list(:service, 3, category: category, is_active: true) }
    let!(:other_services) { create_list(:service, 2, category: other_category, is_active: true) }
    let!(:inactive_service) { create(:service, :inactive, category: category) }
    
    context "without authentication" do
      it "returns services for the category" do
        get "/api/v1/service_categories/#{category.id}/services"
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['data']).to be_an(Array)
        expect(json['data'].length).to eq(4) # 3 active + 1 inactive
        expect(json['pagination']).to include(
          'current_page' => 1,
          'total_count' => 4,
          'per_page' => 10
        )
        
        # Проверяем, что включена информация о категории
        json['data'].each do |service|
          expect(service['category']).to include(
            'id' => category.id,
            'name' => category.name
          )
        end
      end
    end
    
    context "with pagination" do
      it "respects page and per_page parameters" do
        get "/api/v1/service_categories/#{category.id}/services", 
            params: { page: 1, per_page: 2 }
        
        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(2)
        expect(json['pagination']['per_page']).to eq(2)
      end
    end
    
    context "with search" do
      let!(:searchable_service) { create(:service, name: "Замена шин R16", category: category) }
      
      it "filters services by name" do
        get "/api/v1/service_categories/#{category.id}/services", 
            params: { query: "Замена шин" }
        
        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(1)
        expect(json['data'].first['name']).to include("Замена шин")
      end
      
      it "performs case-insensitive search" do
        get "/api/v1/service_categories/#{category.id}/services", 
            params: { query: "замена шин" }
        
        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(1)
      end
    end
    
    context "with active filter" do
      it "returns only active services when active=true" do
        get "/api/v1/service_categories/#{category.id}/services", 
            params: { active: 'true' }
        
        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(3)
        json['data'].each do |service|
          expect(service['is_active']).to be true
        end
      end
    end
    
    context "with sorting" do
      it "sorts by name by default" do
        get "/api/v1/service_categories/#{category.id}/services"
        
        json = JSON.parse(response.body)
        names = json['data'].map { |service| service['name'] }
        expect(names).to eq(names.sort)
      end
      
      it "sorts by default_duration when specified" do
        category_services.first.update(default_duration: 30)
        category_services.second.update(default_duration: 60)
        
        get "/api/v1/service_categories/#{category.id}/services", 
            params: { sort: 'default_duration' }
        
        json = JSON.parse(response.body)
        durations = json['data'].map { |service| service['default_duration'] }
        expect(durations).to eq(durations.sort)
      end
    end
    
    it "returns 404 for non-existent category" do
      get "/api/v1/service_categories/99999/services"
      
      expect(response).to have_http_status(:not_found)
    end
  end
  
  describe "GET /api/v1/services" do
    let!(:all_services) { create_list(:service, 5, is_active: true) }
    
    it "returns all services across categories" do
      get "/api/v1/services"
      
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      
      expect(json['data']).to be_an(Array)
      expect(json['data'].length).to eq(5)
    end
  end
  
  describe "GET /api/v1/service_categories/:service_category_id/services/:id" do
    let(:service) { create(:service, category: category) }
    
    it "returns service details" do
      get "/api/v1/service_categories/#{category.id}/services/#{service.id}"
      
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      
      expect(json['id']).to eq(service.id)
      expect(json['name']).to eq(service.name)
      expect(json['category']).to include(
        'id' => category.id,
        'name' => category.name
      )
    end
    
    it "returns 404 for non-existent service" do
      get "/api/v1/service_categories/#{category.id}/services/99999"
      
      expect(response).to have_http_status(:not_found)
    end
  end
  
  describe "POST /api/v1/service_categories/:service_category_id/services" do
    let(:valid_attributes) do
      {
        service: {
          name: "Новая услуга",
          description: "Описание новой услуги",
          default_duration: 45,
          is_active: true,
          sort_order: 1
        }
      }
    end
    
    context "as admin" do
      it "creates a new service" do
        expect {
          post "/api/v1/service_categories/#{category.id}/services", 
               params: valid_attributes, 
               headers: admin_headers
        }.to change(Service, :count).by(1)
        
        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['name']).to eq("Новая услуга")
        expect(json['category']['id']).to eq(category.id)
        
        # Проверяем, что услуга привязана к правильной категории
        created_service = Service.last
        expect(created_service.category_id).to eq(category.id)
      end
      
      it "returns errors for invalid data" do
        post "/api/v1/service_categories/#{category.id}/services", 
             params: { service: { name: "", default_duration: -1 } }, 
             headers: admin_headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end
    
    context "as regular user" do
      it "denies access" do
        post "/api/v1/service_categories/#{category.id}/services", 
             params: valid_attributes, 
             headers: user_headers
        
        expect(response).to have_http_status(:forbidden)
      end
    end
    
    context "without authentication" do
      it "denies access" do
        post "/api/v1/service_categories/#{category.id}/services", 
             params: valid_attributes
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
  
  describe "PUT /api/v1/service_categories/:service_category_id/services/:id" do
    let(:service) { create(:service, category: category) }
    let(:update_attributes) do
      {
        service: {
          name: "Обновленная услуга",
          description: "Новое описание",
          default_duration: 90
        }
      }
    end
    
    context "as admin" do
      it "updates the service" do
        put "/api/v1/service_categories/#{category.id}/services/#{service.id}", 
            params: update_attributes, 
            headers: admin_headers
        
        expect(response).to have_http_status(:ok)
        service.reload
        expect(service.name).to eq("Обновленная услуга")
        expect(service.default_duration).to eq(90)
      end
      
      it "returns errors for invalid data" do
        put "/api/v1/service_categories/#{category.id}/services/#{service.id}", 
            params: { service: { name: "", default_duration: -1 } }, 
            headers: admin_headers
        
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
    
    context "as regular user" do
      it "denies access" do
        put "/api/v1/service_categories/#{category.id}/services/#{service.id}", 
            params: update_attributes, 
            headers: user_headers
        
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
  
  describe "DELETE /api/v1/service_categories/:service_category_id/services/:id" do
    let(:service) { create(:service, category: category) }
    
    context "as admin" do
      it "deletes the service" do
        service_id = service.id
        
        expect {
          delete "/api/v1/service_categories/#{category.id}/services/#{service_id}", 
                 headers: admin_headers
        }.to change(Service, :count).by(-1)
        
        expect(response).to have_http_status(:no_content)
      end
    end
    
    context "as regular user" do
      it "denies access" do
        delete "/api/v1/service_categories/#{category.id}/services/#{service.id}", 
               headers: user_headers
        
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
  
  private
  
  def generate_token(user)
    # Предполагаем, что у вас есть метод для генерации JWT токена
    # Адаптируйте под вашу систему аутентификации
    payload = { user_id: user.id, exp: 24.hours.from_now.to_i }
    JWT.encode(payload, Rails.application.credentials.secret_key_base)
  end
end
