Rails.application.routes.draw do
  # Mount Rswag engines
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API Routes
  namespace :api do
    namespace :v1 do
      # Управление контентом страниц
      resources :page_contents do
        collection do
          get 'sections'
        end
        member do
          patch 'toggle_active'
        end
      end
      # Health check endpoint
      get 'health', to: 'health#index'
      
      # Аутентификация
      post 'auth/login', to: 'auth#login'
      post 'auth/logout', to: 'auth#logout'
      get 'auth/me', to: 'auth#me'
      post 'auth/refresh', to: 'auth#refresh'
      put 'auth/profile', to: 'auth#update_profile'
      
      # Автомобили текущего клиента
      get 'auth/me/cars', to: 'auth#my_cars'
      post 'auth/me/cars', to: 'auth#create_car'
      patch 'auth/me/cars/:car_id', to: 'auth#update_car'
      delete 'auth/me/cars/:car_id', to: 'auth#delete_car'
      
      # Клиентский API доступности (упрощенный)
      get 'availability/:service_point_id/:date', to: 'availability#client_available_times'
      post 'bookings/check_availability', to: 'availability#client_check_availability'
      
      # API доступности с поддержкой категорий
      post 'availability/check_with_category', to: 'availability#check_with_category'
      get 'availability/slots_for_category', to: 'availability#slots_for_category'
      
      # Клиентский API поиска сервисных точек  
      get 'service_points/search', to: 'service_points#client_search'
      
      # Клиентский API записей (включая гостевые записи)
      resources :client_bookings, only: [:create, :show, :update, :destroy] do
        member do
          delete :cancel, to: 'client_bookings#cancel'
          post :reschedule, to: 'client_bookings#reschedule'
        end
        collection do
          post :check_availability_for_booking, to: 'client_bookings#check_availability_for_booking'
        end
      end
      
      # Клиентская авторизация (опциональная)
      scope 'clients' do
        post 'register', to: 'client_auth#register'
        post 'login', to: 'client_auth#login'
        post 'logout', to: 'client_auth#logout'
        get 'me', to: 'client_auth#me'
      end
      
      # Dashboard statistics
      get 'dashboard/stats', to: 'dashboard#stats'
      get 'dashboard/charts/bookings', to: 'dashboard#charts_bookings'
      get 'dashboard/charts/revenue', to: 'dashboard#charts_revenue'
      get 'dashboard/top-services', to: 'dashboard#top_services'
      get 'dashboard/partner/:partner_id/stats', to: 'dashboard#partner_stats'
      
      # Партнерская регистрация и аутентификация
      post 'partners/register', to: 'partner_auth#register'
      post 'partners/login', to: 'partner_auth#login'
      
      # Профиль текущего пользователя
      get 'users/me', to: 'users#me'
      
      # Пользователи
      resources :users, only: [:index, :show, :create, :update, :destroy] do
        member do
          patch :toggle_active
        end
        collection do
          get :check_exists
        end
      end
      
      # Администраторы
      resources :administrators, only: [:index, :show, :create, :update, :destroy]
      
      # Партнеры
      resources :partners, only: [:index, :show, :create, :update, :destroy] do
        resources :service_points, only: [:index, :show, :create, :update, :destroy]
        resources :managers, only: [:index, :show, :create, :update, :destroy] do
          collection do
            post 'create_test', to: 'managers#create_test'
          end
        end
        resources :price_lists, only: [:index, :show, :create, :update, :destroy]
        resources :promotions, only: [:index, :show, :create, :update, :destroy]
        resources :operators, only: [:index, :create]
        
        # Создание тестовых данных для партнера
        collection do
          post 'create_test', to: 'partners#create_test'
        end
        
        # Активация/деактивация партнера
        member do
          patch 'toggle_active', to: 'partners#toggle_active'
        end
      end
      
      # Менеджеры
      resources :managers, only: [] do
        resources :service_points, only: [:index]
      end
      
      # Статусы сервисных точек
      get 'service_point_statuses', to: 'service_points#statuses'
      
      # Специальные эндпоинты для сервисных точек (должны быть ДО resources)
      get 'service_points/work_statuses', to: 'service_points#work_statuses'
      
      # Сервисные точки
      resources :service_points, only: [:index, :show] do
        member do
          get 'basic', to: 'service_points#basic'
          get 'schedule', to: 'schedule#day'
          get 'client_details', to: 'service_points#client_details'
          get 'posts_by_category', to: 'service_points#posts_by_category'
          patch 'category_contacts', to: 'service_points#update_category_contacts'
        end
        
        collection do
          get 'by_category', to: 'service_points#by_category'
        end
        
        # Новое API для динамической доступности
        member do
          get 'availability/week', to: 'availability#week_overview', as: 'week_overview'
          get 'availability/:date', to: 'availability#available_times', as: 'availability_times'
          post 'availability/check', to: 'availability#check_time'
          get 'availability/:date/next', to: 'availability#next_available', as: 'next_available'
          get 'availability/:date/details', to: 'availability#day_details', as: 'day_details'
          get 'availability/:date/check', to: 'availability#check_day_availability', as: 'check_day_availability'
        end
        
        resources :schedule_templates, only: [:index, :show, :create, :update, :destroy]
        resources :schedule_exceptions, only: [:index, :show, :create, :update, :destroy]
        resources :schedule_slots, only: [:index, :show, :create, :update, :destroy]
        resources :amenities, only: [:index, :create, :destroy]
        resources :reviews, only: [:index, :show]
        resources :bookings, only: [:index, :show]
        resources :photos, controller: 'service_point_photos'
        resources :services, only: [:index, :create, :destroy], controller: 'service_point_services'
        
        # Посты обслуживания
        resources :service_posts do
          member do
            post 'activate'
            post 'deactivate'
          end
          
          collection do
            post 'create_defaults'
            get 'statistics'
          end
        end
        
        # Добавляем маршруты для управления расписанием
        member do
          post 'generate_schedule', to: 'service_points#generate_schedule'
          get 'available_slots', to: 'service_points#available_slots'
          get 'occupancy', to: 'service_points#occupancy'
          get 'weekly_occupancy', to: 'service_points#weekly_occupancy'
          get 'posts_schedule', to: 'service_points#posts_schedule'
          get 'schedule_preview', to: 'service_points#schedule_preview'
          post 'calculate_schedule_preview', to: 'service_points#calculate_schedule_preview'
        end
        
        collection do
          get 'nearby', to: 'service_points#nearby'
        end
      end
      
      # Отзывы (прямые маршруты для админов)
      resources :reviews, only: [:index, :show, :create, :update, :destroy]
      
      # Клиенты
      resources :clients, only: [:index, :show, :create, :update, :destroy] do
        resources :cars, only: [:index, :show, :create, :update, :destroy]
        resources :bookings, only: [:index, :show, :create, :update, :destroy]
        resources :favorite_points, only: [:index, :create, :destroy]
        resources :reviews, only: [:index, :show, :create, :update, :destroy]
        
        # Создание тестового клиента
        collection do
          post 'create_test', to: 'clients#create_test'
        end
      end
      
      # Создание тестовых клиентов и социальная авторизация
      post 'clients/social_auth', to: 'clients#social_auth'
      
      # Каталоги
      resources :regions, only: [:index, :show, :create, :update, :destroy]
      resources :cities, only: [:index, :show, :create, :update, :destroy] do
        collection do
          get :with_service_points
        end
      end
      resources :car_brands do
        resources :car_models
      end
      resources :car_models
      resources :car_types, only: [:index, :show]
      resources :tire_types, only: [:index, :show]
      resources :service_categories do
        collection do
          get 'by_city/:city_name', to: 'service_categories#by_city', as: 'by_city'
          get 'by_city_id/:city_id', to: 'service_categories#by_city_id', as: 'by_city_id'
        end
        resources :services
      end
      resources :services
      resources :booking_statuses, only: [:index, :show]
      resources :payment_statuses, only: [:index, :show]
      resources :cancellation_reasons, only: [:index, :show]
      resources :amenities, only: [:index, :show]
      
      # Статьи и контент
      resources :articles do
        collection do
          get 'categories'
          get 'popular'
        end
        member do
          get 'related'
        end
      end
      
      # Бронирования
      resources :bookings, only: [:index, :show, :create, :update, :destroy] do
        member do
          post 'confirm', to: 'bookings#confirm'
          post 'cancel', to: 'bookings#cancel'
          post 'complete', to: 'bookings#complete'
          post 'no_show', to: 'bookings#no_show'
        end
      end
      
      # Расписание
      get 'schedule/:service_point_id/:date', to: 'schedule#day', as: 'schedule_day'
      get 'schedule/:service_point_id/:from_date/:to_date', to: 'schedule#period', as: 'schedule_period'
      post 'schedule/generate_for_date/:service_point_id/:date', to: 'schedule#generate_for_date', as: 'generate_schedule_for_date'
      post 'schedule/generate_for_period/:service_point_id/:from_date/:to_date', to: 'schedule#generate_for_period', as: 'generate_schedule_for_period'
      
      # Уведомления
      resources :notifications, only: [:index, :show, :update]
      
      # Системные логи (только для администраторов)
      resources :system_logs, only: [:index, :show]
      
      # Тестовые данные для разработки
      namespace :tests do
        get 'generate_data', to: 'data_generator#generate'
        post 'create_test_client', to: 'data_generator#create_test_client'
        post 'create_test_partner', to: 'data_generator#create_test_partner'
        post 'create_test_service_point', to: 'data_generator#create_test_service_point'
        post 'create_test_booking', to: 'data_generator#create_test_booking'
      end
      
      resources :service_point_statuses, only: [:index]

      # Отзывы
      resources :reviews
      
      # Клиентские ресурсы
      resources :clients do
        resources :reviews
        resources :cars, controller: 'client_cars'
        resources :bookings
        resources :favorite_points, only: [:index, :create, :destroy]
      end
      
      # Ресурсы сервисных точек
      resources :service_points do
        resources :reviews, only: [:index, :show]
        resources :services
        resources :bookings
        resources :working_hours
        resources :holidays
        resources :availability, only: [:index]
      end
      
      # Другие ресурсы
      resources :car_brands
      resources :car_models
      resources :car_types
      resources :service_categories
      resources :service_types
      resources :booking_statuses
      resources :payment_statuses
      resources :cancellation_reasons
      resources :regions
      resources :cities

      # Маршруты для ролей пользователей
      resources :user_roles, only: [:index, :show]

      resources :operators, only: [:update, :destroy]
    end
  end
end
