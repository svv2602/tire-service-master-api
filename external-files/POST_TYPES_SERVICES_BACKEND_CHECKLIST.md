# 📋 BACKEND ЧЕКЛИСТ: ТИПЫ ПОСТОВ И КАТЕГОРИИ УСЛУГ

## 🎯 ЦЕЛЬ BACKEND ЧАСТИ
Реализовать backend функционал для системы категорий услуг:
- **ОБЯЗАТЕЛЬНАЯ** связь постов с категориями (NOT NULL)
- JSON поле для контактных телефонов по категориям
- API для фильтрации точек по категориям
- Логика расчета доступности с учетом категорий
- Поддержка категорий в бронированиях

---

## 🗄️ ЭТАП 1: МИГРАЦИИ БАЗЫ ДАННЫХ

### 1.1 Поэтапные миграции

- [ ] **Миграция 1: Добавление поля service_category_id (nullable)**
  ```ruby
  # db/migrate/20250627_add_service_category_to_service_posts.rb
  class AddServiceCategoryToServicePosts < ActiveRecord::Migration[8.0]
    def change
      add_reference :service_posts, :service_category, null: true, foreign_key: true
      add_index :service_posts, [:service_point_id, :service_category_id]
    end
  end
  ```

- [ ] **Миграция 2: Назначение дефолтной категории**
  ```ruby
  # db/migrate/20250627_assign_default_categories_to_posts.rb
  class AssignDefaultCategoriesToPosts < ActiveRecord::Migration[8.0]
    def up
      default_category = ServiceCategory.find_or_create_by!(
        name: 'Общие услуги',
        description: 'Универсальная категория для постов без специализации',
        is_active: true,
        sort_order: 999
      )
      
      ServicePost.where(service_category_id: nil).update_all(
        service_category_id: default_category.id
      )
    end
    
    def down
      ServicePost.where(service_category_id: ServiceCategory.find_by(name: 'Общие услуги')&.id)
                 .update_all(service_category_id: nil)
    end
  end
  ```

- [ ] **Миграция 3: Обязательность поля (NOT NULL)**
  ```ruby
  # db/migrate/20250627_make_service_category_required_in_posts.rb
  class MakeServiceCategoryRequiredInPosts < ActiveRecord::Migration[8.0]
    def change
      change_column_null :service_posts, :service_category_id, false
    end
  end
  ```

- [ ] **Миграция 4: Категория в бронированиях**
  ```ruby
  # db/migrate/20250627_add_service_category_to_bookings.rb
  class AddServiceCategoryToBookings < ActiveRecord::Migration[8.0]
    def change
      add_reference :bookings, :service_category, null: true, foreign_key: true
      add_index :bookings, :service_category_id
    end
  end
  ```

- [ ] **Миграция 5: JSON контакты по категориям**
  ```ruby
  # db/migrate/20250627_add_category_contacts_to_service_points.rb
  class AddCategoryContactsToServicePoints < ActiveRecord::Migration[8.0]
    def change
      add_column :service_points, :category_contacts, :jsonb, default: {}
      add_index :service_points, :category_contacts, using: :gin
    end
  end
  ```

### 1.2 Проверка миграций

- [ ] **Тест миграций в development**
  ```bash
  rails db:migrate
  rails db:rollback STEP=5
  rails db:migrate
  ```

- [ ] **Проверка целостности данных**
  ```ruby
  # Все посты должны иметь категорию
  ServicePost.where(service_category_id: nil).count # => 0
  
  # Проверка foreign key constraints
  ServicePost.joins(:service_category).count
  ```

---

## 🏗️ ЭТАП 2: ОБНОВЛЕНИЕ МОДЕЛЕЙ

### 2.1 ServicePost

- [ ] **Обновить модель ServicePost**
  ```ruby
  # app/models/service_post.rb
  class ServicePost < ApplicationRecord
    belongs_to :service_point
    belongs_to :service_category # УБИРАЕМ optional: true
    
    validates :service_category_id, presence: true
    validates :post_number, presence: true, uniqueness: { scope: :service_point_id }
    
    scope :by_category, ->(category_id) { where(service_category_id: category_id) }
    scope :with_category, -> { includes(:service_category) }
    scope :active, -> { where(is_active: true) }
    
    def category_name
      service_category.name
    end
    
    def supports_category?(category_id)
      service_category_id == category_id
    end
    
    def available_at_time?(datetime)
      # Логика проверки доступности поста в указанное время
      return false unless is_active?
      
      # Проверяем расписание работы поста
      # Проверяем существующие бронирования
      true
    end
  end
  ```

### 2.2 ServicePoint

- [ ] **Обновить модель ServicePoint**
  ```ruby
  # app/models/service_point.rb
  class ServicePoint < ApplicationRecord
    # Существующие связи...
    has_many :service_posts, dependent: :destroy
    
    # JSON структура category_contacts:
    # {
    #   "1": { "phone": "+380671234567", "email": "tire@example.com" },
    #   "2": { "phone": "+380671234568", "email": "wash@example.com" }
    # }
    
    def posts_for_category(category_id)
      service_posts.active.by_category(category_id)
    end
    
    def posts_count_for_category(category_id)
      posts_for_category(category_id).count
    end
    
    def contact_phone_for_category(category_id)
      category_contacts.dig(category_id.to_s, 'phone')
    end
    
    def contact_email_for_category(category_id)
      category_contacts.dig(category_id.to_s, 'email')
    end
    
    def set_category_contact(category_id, phone:, email: nil)
      self.category_contacts = category_contacts.merge(
        category_id.to_s => { 'phone' => phone, 'email' => email }.compact
      )
    end
    
    def remove_category_contact(category_id)
      updated_contacts = category_contacts.dup
      updated_contacts.delete(category_id.to_s)
      self.category_contacts = updated_contacts
    end
    
    def supports_category?(category_id)
      posts_for_category(category_id).exists?
    end
    
    def available_categories
      service_posts.includes(:service_category).map(&:service_category).uniq
    end
    
    def category_statistics
      service_posts.joins(:service_category)
                   .group('service_categories.name')
                   .count
    end
  end
  ```

### 2.3 Booking

- [x] **Обновить модель Booking**
  ```ruby
  # app/models/booking.rb
  class Booking < ApplicationRecord
    # Существующие связи...
    belongs_to :service_category, optional: true
    
    # Скоупы для работы с категориями
    scope :by_category, ->(category_id) { where(service_category_id: category_id) }
    scope :with_category, -> { includes(:service_category) }
    
    # Валидация категории
    validate :service_category_matches_service_point, if: :service_category_id?
    
    private
    
    def service_category_matches_service_point
      return unless service_category_id.present? && service_point_id.present?
      
      unless service_point.supports_category?(service_category_id)
        errors.add(:service_category_id, "не поддерживается данной сервисной точкой")
      end
    end
  end
  ```

---

## 🌐 ЭТАП 3: API КОНТРОЛЛЕРЫ

### 3.1 ServicePointsController

- [x] **Добавить методы для работы с категориями**
  ```ruby
  # app/controllers/api/v1/service_points_controller.rb
  class Api::V1::ServicePointsController < ApiController
    # GET /api/v1/service_points/by_category?category_id=1&city_id=1
    def by_category
      category_id = params[:category_id]
      city_id = params[:city_id]
      
      return render json: { error: 'Параметр category_id обязателен' }, status: :bad_request unless category_id
      
      service_points = ServicePoint.joins(:service_posts)
                                   .where(service_posts: { service_category_id: category_id, is_active: true })
                                   .where(is_active: true)
      
      service_points = service_points.where(city_id: city_id) if city_id.present?
      
      paginated_points = service_points.distinct
                                       .includes(:city, :partner, service_posts: :service_category)
                                       .page(params[:page])
                                       .per(params[:per_page] || 20)
      
      render json: {
        data: paginated_points.map { |sp| ServicePointSerializer.new(sp).as_json },
        total_count: service_points.distinct.count,
        current_page: paginated_points.current_page,
        total_pages: paginated_points.total_pages
      }
    end
    
    # GET /api/v1/service_points/:id/posts_by_category?category_id=1
    def posts_by_category
      category_id = params[:category_id]
      
      return render json: { error: 'Параметр category_id обязателен' }, status: :bad_request unless category_id
      
      posts = @service_point.posts_for_category(category_id)
      
      render json: {
        data: posts.includes(:service_category).map { |post| ServicePostSerializer.new(post).as_json },
        category_contact: {
          phone: @service_point.contact_phone_for_category(category_id),
          email: @service_point.contact_email_for_category(category_id)
        },
        posts_count: posts.count
      }
    end
    
    # PATCH /api/v1/service_points/:id/category_contacts
    def update_category_contacts
      contacts_data = params[:category_contacts] || {}
      
      begin
        contacts_data.each do |category_id, contact_info|
          next unless contact_info.is_a?(Hash)
          
          @service_point.set_category_contact(
            category_id,
            phone: contact_info[:phone],
            email: contact_info[:email]
          )
        end
        
        if @service_point.save
          render json: { 
            success: true, 
            category_contacts: @service_point.category_contacts,
            message: 'Контакты успешно обновлены'
          }
        else
          render json: { errors: @service_point.errors }, status: :unprocessable_entity
        end
      rescue => e
        render json: { error: "Ошибка обновления контактов: #{e.message}" }, status: :internal_server_error
      end
    end
  end
  ```

### 3.2 BookingsController

- [ ] **Добавить поддержку категорий**

### 3.3 AvailabilityController

- [x] **Создать контроллер для проверки доступности с категориями**
  ```ruby
  # app/controllers/api/v1/availability_controller.rb
  class Api::V1::AvailabilityController < Api::V1::BaseController
    def check_with_category
      # POST /api/v1/availability/check_with_category
      service_point_id = params[:servicePointId]
      date = params[:date]
      start_time = params[:startTime]
      duration = params[:duration]&.to_i || 60
      category_id = params[:categoryId]
      
      # Валидация параметров
      required_params = [service_point_id, date, start_time, category_id]
      if required_params.any?(&:blank?)
        return render json: { 
          error: 'Не все обязательные параметры переданы' 
        }, status: :bad_request
      end
      
      begin
        result = DynamicAvailabilityService.check_availability_with_category(
          service_point_id, date, start_time, duration, category_id
        )
        
        render json: result
      rescue => e
        render json: { 
          error: "Ошибка проверки доступности: #{e.message}" 
        }, status: :internal_server_error
      end
    end
  end
  ```

---

## 🔧 ЭТАП 4: СЕРВИСЫ

### 4.1 DynamicAvailabilityService

- [ ] **Обновить сервис проверки доступности**
  ```ruby
  # app/services/dynamic_availability_service.rb
  class DynamicAvailabilityService
    def self.check_availability_with_category(service_point_id, date, start_time, duration, category_id)
      service_point = ServicePoint.find(service_point_id)
      
      # Получаем посты только для указанной категории
      available_posts = service_point.posts_for_category(category_id)
      
      return {
        available: false,
        reason: 'Нет активных постов для данной категории услуг',
        available_posts_count: 0,
        total_posts_count: 0
      } if available_posts.empty?
      
      # Парсим время
      datetime = DateTime.parse("#{date} #{start_time}")
      end_datetime = datetime + duration.minutes
      
      available_posts_count = 0
      
      available_posts.each do |post|
        # Проверяем доступность поста в указанное время
        next unless post.available_at_time?(datetime)
        
        # Проверяем пересечения с существующими бронированиями
        overlapping_bookings = Booking.where(service_point: service_point)
                                      .where(booking_date: date)
                                      .where('start_time < ? AND end_time > ?', 
                                             end_datetime.strftime('%H:%M'), 
                                             start_time)
                                      .where.not(status_id: BookingStatus.canceled_statuses)
        
        # Если количество пересечений меньше доступных постов - есть свободный пост
        if overlapping_bookings.count < available_posts.count
          available_posts_count += 1
        end
      end
      
      {
        available: available_posts_count > 0,
        reason: available_posts_count > 0 ? nil : 'Все посты данной категории заняты на выбранное время',
        available_posts_count: available_posts_count,
        total_posts_count: available_posts.count,
        category_contact: {
          phone: service_point.contact_phone_for_category(category_id),
          email: service_point.contact_email_for_category(category_id)
        }
      }
    rescue => e
      {
        available: false,
        reason: "Ошибка проверки доступности: #{e.message}",
        available_posts_count: 0,
        total_posts_count: 0
      }
    end
  end
  ```

### 4.2 CategoryFilterService

- [ ] **Создать сервис для фильтрации по категориям**
  ```ruby
  # app/services/category_filter_service.rb
  class CategoryFilterService
    def self.service_points_with_category(category_id, city_id = nil, limit: 20, offset: 0)
      query = ServicePoint.joins(:service_posts)
                          .where(service_posts: { service_category_id: category_id, is_active: true })
                          .where(is_active: true)
      
      query = query.where(city_id: city_id) if city_id.present?
      
      {
        data: query.distinct
                   .includes(:city, :partner, service_posts: :service_category)
                   .limit(limit)
                   .offset(offset),
        total_count: query.distinct.count
      }
    end
    
    def self.available_time_slots_by_category(service_point_id, date, category_id, duration = 60)
      service_point = ServicePoint.find(service_point_id)
      posts = service_point.posts_for_category(category_id)
      
      return [] if posts.empty?
      
      # Генерируем временные слоты для каждого поста категории
      available_slots = []
      
      posts.each do |post|
        post_slots = generate_slots_for_post(post, date, duration)
        available_slots.concat(post_slots)
      end
      
      # Убираем дубликаты и сортируем
      available_slots.uniq.sort
    end
    
    def self.category_statistics(service_point_id = nil)
      query = service_point_id ? ServicePost.where(service_point_id: service_point_id) : ServicePost.all
      
      query.joins(:service_category)
           .group('service_categories.name')
           .count
    end
    
    private
    
    def self.generate_slots_for_post(post, date, duration)
      # Логика генерации временных слотов для конкретного поста
      # Учитываем индивидуальное расписание поста
      # Проверяем существующие бронирования
      
      slots = []
      start_hour = 9  # Начало рабочего дня
      end_hour = 18   # Конец рабочего дня
      
      (start_hour...end_hour).each do |hour|
        [0, 30].each do |minute|  # Слоты каждые 30 минут
          time_slot = "#{hour.to_s.rjust(2, '0')}:#{minute.to_s.rjust(2, '0')}"
          
          # Проверяем доступность слота
          if slot_available?(post, date, time_slot, duration)
            slots << time_slot
          end
        end
      end
      
      slots
    end
    
    def self.slot_available?(post, date, time_slot, duration)
      # Проверяем доступность конкретного слота для поста
      datetime = DateTime.parse("#{date} #{time_slot}")
      end_datetime = datetime + duration.minutes
      
      # Проверяем пересечения с существующими бронированиями
      overlapping_bookings = Booking.where(service_point: post.service_point)
                                    .where(booking_date: date)
                                    .where('start_time < ? AND end_time > ?', 
                                           end_datetime.strftime('%H:%M'), 
                                           time_slot)
                                    .where.not(status_id: BookingStatus.canceled_statuses)
      
      overlapping_bookings.empty?
    end
  end
  ```

---

## 🛣️ ЭТАП 5: РОУТЫ

- [ ] **Обновить config/routes.rb**
  ```ruby
  # config/routes.rb
  Rails.application.routes.draw do
    namespace :api do
      namespace :v1 do
        resources :service_points do
          collection do
            get :by_category
          end
          
          member do
            get :posts_by_category
            patch :category_contacts, to: 'service_points#update_category_contacts'
          end
        end
        
        # Новые роуты для проверки доступности
        namespace :availability do
          post :check_with_category
        end
        
        # Обновленные роуты для бронирований с поддержкой категорий
        resources :bookings do
          collection do
            get :by_category
          end
        end
      end
    end
  end
  ```

---

## 🧪 ЭТАП 6: ТЕСТИРОВАНИЕ

### 6.1 Тесты моделей

- [ ] **Тесты ServicePost**
  ```ruby
  # spec/models/service_post_spec.rb
  RSpec.describe ServicePost, type: :model do
    describe 'associations' do
      it { should belong_to(:service_category) }
    end
    
    describe 'validations' do
      it { should validate_presence_of(:service_category_id) }
    end
    
    describe 'scopes' do
      let!(:category1) { create(:service_category) }
      let!(:category2) { create(:service_category) }
      let!(:post1) { create(:service_post, service_category: category1) }
      let!(:post2) { create(:service_post, service_category: category2) }
      
      it 'filters posts by category' do
        expect(ServicePost.by_category(category1.id)).to include(post1)
        expect(ServicePost.by_category(category1.id)).not_to include(post2)
      end
    end
  end
  ```

- [ ] **Тесты ServicePoint**
  ```ruby
  # spec/models/service_point_spec.rb
  RSpec.describe ServicePoint, type: :model do
    describe 'category methods' do
      let(:service_point) { create(:service_point) }
      let(:category) { create(:service_category) }
      let!(:post) { create(:service_post, service_point: service_point, service_category: category) }
      
      it 'returns posts for specific category' do
        expect(service_point.posts_for_category(category.id)).to include(post)
      end
      
      it 'checks if category is supported' do
        expect(service_point.supports_category?(category.id)).to be true
      end
      
      it 'manages category contacts' do
        service_point.set_category_contact(category.id, phone: '+380671234567', email: 'test@example.com')
        expect(service_point.contact_phone_for_category(category.id)).to eq('+380671234567')
        expect(service_point.contact_email_for_category(category.id)).to eq('test@example.com')
      end
    end
  end
  ```

### 6.2 Тесты API

- [ ] **Тесты ServicePointsController**
  ```ruby
  # spec/requests/api/v1/service_points_spec.rb
  RSpec.describe 'Api::V1::ServicePoints', type: :request do
    describe 'GET /api/v1/service_points/by_category' do
      let!(:category) { create(:service_category) }
      let!(:service_point) { create(:service_point) }
      let!(:post) { create(:service_post, service_point: service_point, service_category: category) }
      
      it 'returns service points for specific category' do
        get "/api/v1/service_points/by_category", params: { category_id: category.id }
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data']).not_to be_empty
        expect(json_response['total_count']).to eq(1)
      end
      
      it 'returns error without category_id' do
        get "/api/v1/service_points/by_category"
        
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('category_id обязателен')
      end
    end
  end
  ```

### 6.3 Тесты сервисов

- [ ] **Тесты DynamicAvailabilityService**
  ```ruby
  # spec/services/dynamic_availability_service_spec.rb
  RSpec.describe DynamicAvailabilityService do
    describe '.check_availability_with_category' do
      let(:service_point) { create(:service_point) }
      let(:category) { create(:service_category) }
      let!(:post) { create(:service_post, service_point: service_point, service_category: category) }
      
      it 'returns available when posts exist for category' do
        result = described_class.check_availability_with_category(
          service_point.id, Date.current.to_s, '10:00', 60, category.id
        )
        
        expect(result[:available]).to be true
        expect(result[:available_posts_count]).to eq(1)
        expect(result[:total_posts_count]).to eq(1)
      end
      
      it 'returns unavailable when no posts for category' do
        other_category = create(:service_category)
        
        result = described_class.check_availability_with_category(
          service_point.id, Date.current.to_s, '10:00', 60, other_category.id
        )
        
        expect(result[:available]).to be false
        expect(result[:reason]).to include('Нет активных постов')
      end
    end
  end
  ```

---

## 📊 ЭТАП 7: SEEDS И ТЕСТОВЫЕ ДАННЫЕ

- [ ] **Обновить seeds для категорий и постов**
  ```ruby
  # db/seeds/service_categories_and_posts.rb
  
  puts "Создание категорий услуг..."
  
  tire_service = ServiceCategory.find_or_create_by!(name: 'Шиномонтаж') do |category|
    category.description = 'Услуги по замене и ремонту шин'
    category.sort_order = 1
    category.is_active = true
  end
  
  car_wash = ServiceCategory.find_or_create_by!(name: 'Автомойка') do |category|
    category.description = 'Услуги по мойке автомобилей'
    category.sort_order = 2
    category.is_active = true
  end
  
  car_service = ServiceCategory.find_or_create_by!(name: 'СТО') do |category|
    category.description = 'Техническое обслуживание и ремонт автомобилей'
    category.sort_order = 3
    category.is_active = true
  end
  
  puts "Назначение категорий постам и настройка контактов..."
  
  ServicePoint.includes(:service_posts).find_each do |service_point|
    # Назначаем категории постам
    service_point.service_posts.each_with_index do |post, index|
      category = [tire_service, car_wash, car_service][index % 3]
      post.update!(service_category: category)
    end
    
    # Настраиваем контактные телефоны
    service_point.update!(
      category_contacts: {
        tire_service.id.to_s => { 
          phone: "+38067#{rand(1000000..9999999)}", 
          email: 'tire@example.com' 
        },
        car_wash.id.to_s => { 
          phone: "+38067#{rand(1000000..9999999)}", 
          email: 'wash@example.com' 
        },
        car_service.id.to_s => { 
          phone: "+38067#{rand(1000000..9999999)}", 
          email: 'service@example.com' 
        }
      }
    )
    
    print "."
  end
  
  puts "\nГотово! Обновлено #{ServicePoint.count} сервисных точек"
  puts "Всего постов: #{ServicePost.count}"
  puts "Посты по категориям:"
  ServicePost.joins(:service_category).group('service_categories.name').count.each do |category, count|
    puts "  #{category}: #{count}"
  end
  ```

---

## ✅ КРИТЕРИИ ГОТОВНОСТИ BACKEND

### Обязательные требования:
- [ ] **Все миграции выполнены успешно**
- [ ] **ВСЕ посты имеют назначенную категорию (NOT NULL)**
- [ ] **API endpoints работают корректно**
- [ ] **JSON поле category_contacts настроено**
- [ ] **Логика доступности учитывает категории**
- [ ] **Все тесты проходят (покрытие 80%+)**

### Дополнительные требования:
- [ ] **Производительность не снизилась**
- [ ] **Логирование добавлено**
- [ ] **Seeds обновлены**
- [ ] **Документация API обновлена**

---

**Статус**: 🟡 В разработке  
**Ответственный**: Backend команда  
**Приоритет**: Высокий 