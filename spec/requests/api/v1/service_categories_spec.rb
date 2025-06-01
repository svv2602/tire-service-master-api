require 'rails_helper'

RSpec.describe "Api::V1::ServiceCategories", type: :request do
  let(:admin) { create(:admin) }
  let(:user) { create(:client_user) }
  let(:admin_headers) { auth_headers_for_user(admin) }
  let(:user_headers) { auth_headers_for_user(user) }
  
  describe "GET /api/v1/service_categories" do
    before do
      # Более сильная очистка данных перед каждым тестом
      ServiceCategory.delete_all
      Service.delete_all
    end
    
    let!(:active_categories) { create_list(:service_category, 3, is_active: true) }
    let!(:inactive_categories) { create_list(:service_category, 2, is_active: false) }
    let!(:category_with_services) { create(:service_category, :with_services, name: "Уникальный Шиномонтаж", is_active: true) }
    
    context "without authentication" do
      it "returns all active categories by default" do
        get "/api/v1/service_categories"
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['data']).to be_an(Array)
        # Проверяем, что возвращаются только активные категории
        all_active = json['data'].all? { |cat| cat['is_active'] == true }
        expect(all_active).to be true
        
        # Проверяем, что есть минимум наши созданные категории
        expect(json['data'].length).to be >= 4
        expect(json['pagination']).to include(
          'current_page' => 1,
          'total_count' => 4,
          'per_page' => 25
        )
      end
      
      it "includes services_count when requested" do
        get "/api/v1/service_categories"
        
        json = JSON.parse(response.body)
        category_data = json['data'].find { |cat| cat['name'] == "Уникальный Шиномонтаж" }
        
        expect(category_data['services_count']).to eq(3)
      end
    end
    
    context "with pagination" do
      it "respects page and per_page parameters" do
        get "/api/v1/service_categories", params: { page: 1, per_page: 2 }
        
        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(2)
        expect(json['pagination']['per_page']).to eq(2)
        # Общее количество может варьироваться, но должно быть как минимум 4
        expect(json['pagination']['total_count']).to be >= 4
        # Количество страниц зависит от общего количества записей
        expect(json['pagination']['total_pages']).to be >= 2
      end
    end
    
    context "with search" do
      it "filters categories by name" do
        get "/api/v1/service_categories", params: { query: "Уникальный" }
        
        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(1)
        expect(json['data'].first['name']).to include("Уникальный")
      end
      
      it "performs case-insensitive search" do
        get "/api/v1/service_categories", params: { query: "уникальный" }
        
        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(1)
      end
    end
    
    context "with active filter" do
      it "returns only active categories when active=true" do
        get "/api/v1/service_categories", params: { active: 'true' }
        
        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(4)
        json['data'].each do |category|
          expect(category['is_active']).to be true
        end
      end
    end
    
    context "with sorting" do
      it "sorts by name by default" do
        get "/api/v1/service_categories"
        
        json = JSON.parse(response.body)
        names = json['data'].map { |cat| cat['name'] }
        expect(names).to eq(names.sort)
      end
      
      it "sorts by sort_order when specified" do
        active_categories.first.update(sort_order: 1)
        active_categories.second.update(sort_order: 2)
        
        get "/api/v1/service_categories", params: { sort: 'sort_order' }
        
        json = JSON.parse(response.body)
        sort_orders = json['data'].map { |cat| cat['sort_order'] }
        expect(sort_orders).to eq(sort_orders.sort)
      end
    end
  end
  
  describe "GET /api/v1/service_categories/:id" do
    before do
      ServiceCategory.delete_all
      Service.delete_all
    end
    
    let(:category) { create(:service_category, :with_services) }
    
    it "returns category details" do
      get "/api/v1/service_categories/#{category.id}"
      
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      
      expect(json['id']).to eq(category.id)
      expect(json['name']).to eq(category.name)
      expect(json['services']).to be_an(Array)
      expect(json['services'].length).to eq(3)
    end
    
    it "returns 404 for non-existent category" do
      get "/api/v1/service_categories/99999"
      
      expect(response).to have_http_status(:not_found)
    end
  end
  
  describe "POST /api/v1/service_categories" do
    before do
      ServiceCategory.delete_all
      Service.delete_all
    end
    
    let(:valid_attributes) do
      {
        service_category: {
          name: "Новая категория",
          description: "Описание новой категории",
          is_active: true,
          sort_order: 5
        }
      }
    end
    
    context "as admin" do
      it "creates a new service category" do
        expect {
          post "/api/v1/service_categories", params: valid_attributes, headers: admin_headers
        }.to change(ServiceCategory, :count).by(1)
        
        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['name']).to eq("Новая категория")
      end
      
      it "returns errors for invalid data" do
        post "/api/v1/service_categories", 
             params: { service_category: { name: "" } }, 
             headers: admin_headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end
    
    context "as regular user" do
      it "denies access" do
        post "/api/v1/service_categories", params: valid_attributes, headers: user_headers
        
        expect(response).to have_http_status(:forbidden)
      end
    end
    
    context "without authentication" do
      it "denies access" do
        post "/api/v1/service_categories", params: valid_attributes
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
  
  describe "PUT /api/v1/service_categories/:id" do
    before do
      ServiceCategory.delete_all
      Service.delete_all
    end
    
    let(:category) { create(:service_category) }
    let(:update_attributes) do
      {
        service_category: {
          name: "Обновленная категория",
          description: "Новое описание"
        }
      }
    end
    
    context "as admin" do
      it "updates the service category" do
        put "/api/v1/service_categories/#{category.id}", 
            params: update_attributes, 
            headers: admin_headers
        
        expect(response).to have_http_status(:ok)
        category.reload
        expect(category.name).to eq("Обновленная категория")
      end
      
      it "returns errors for invalid data" do
        put "/api/v1/service_categories/#{category.id}", 
            params: { service_category: { name: "" } }, 
            headers: admin_headers
        
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
    
    context "as regular user" do
      it "denies access" do
        put "/api/v1/service_categories/#{category.id}", 
            params: update_attributes, 
            headers: user_headers
        
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
  
  describe "DELETE /api/v1/service_categories/:id" do
    before do
      ServiceCategory.delete_all
      Service.delete_all
    end
    
    let(:category) { create(:service_category) }
    let(:category_with_services) { create(:service_category, :with_services) }
    
    context "as admin" do
      it "deletes category without services" do
        category_id = category.id
        
        expect {
          delete "/api/v1/service_categories/#{category_id}", headers: admin_headers
        }.to change(ServiceCategory, :count).by(-1)
        
        expect(response).to have_http_status(:no_content)
      end
      
      it "prevents deletion of category with services" do
        # Создаем категорию с услугами заранее
        category_with_services = create(:service_category, :with_services)
        
        expect {
          delete "/api/v1/service_categories/#{category_with_services.id}", headers: admin_headers
        }.not_to change(ServiceCategory, :count)
        
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
    
    context "as regular user" do
      it "denies access" do
        delete "/api/v1/service_categories/#{category.id}", headers: user_headers
        
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
