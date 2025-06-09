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
      # Health check endpoint
      get 'health', to: 'health#index'
      
      # Клиентский API доступности (упрощенный)
      get 'availability/:service_point_id/:date', to: 'availability#client_available_times'
      post 'bookings/check_availability', to: 'availability#client_check_availability'
      
      # Dashboard statistics
      get 'dashboard/stats', to: 'dashboard#stats'
      
      # Аутентификация
      post 'auth/login', to: 'auth#login'
      post 'auth/refresh', to: 'auth#refresh'
      post 'auth/logout', to: 'auth#logout'
      # Routes for authentication spec tests
      post 'authenticate', to: 'auth#login'
      post 'register', to: 'clients#register'
      
      # Профиль текущего пользователя
      get 'users/me', to: 'users#me'
      
      # Пользователи
      resources :users, only: [:index, :show, :create, :update, :destroy]
      
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
        end
        
        # Новое API для динамической доступности
        member do
          get 'availability/week', to: 'availability#week_overview', as: 'week_overview'
          get 'availability/:date', to: 'availability#available_times', as: 'availability_times'
          post 'availability/check', to: 'availability#check_time'
          get 'availability/:date/next', to: 'availability#next_available', as: 'next_available'
          get 'availability/:date/details', to: 'availability#day_details', as: 'day_details'
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
      
      # Регистрация клиентов
      post 'clients/register', to: 'clients#register'
      post 'clients/social_auth', to: 'clients#social_auth'
      
      # Каталоги
      resources :regions, only: [:index, :show, :create, :update, :destroy]
      resources :cities, only: [:index, :show, :create, :update, :destroy]
      resources :car_brands do
        resources :car_models
      end
      resources :car_models
      resources :car_types, only: [:index, :show]
      resources :tire_types, only: [:index, :show]
      resources :service_categories do
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
      resources :bookings, only: [:index, :show] do
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
      
      # Добавляем health check эндпоинт
      get 'health', to: 'health#index'
      
      resources :service_point_statuses, only: [:index]
    end
  end
end
