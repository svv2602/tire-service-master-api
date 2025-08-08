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
      # Health check endpoint для Docker
      get '/health', to: 'health#index'
      
      # Поиск шин
      post 'tire_search', to: 'tire_search#search'
      get 'tire_search/suggestions', to: 'tire_search#suggestions'
      get 'tire_search/popular', to: 'tire_search#popular'
      get 'tire_search/brands', to: 'tire_search#brands'
      get 'tire_search/models', to: 'tire_search#models'
      get 'tire_search/diameters', to: 'tire_search#diameters'
      get 'tire_search/statistics', to: 'tire_search#statistics'
      
      # Поиск товаров поставщиков
      post 'supplier_products_search', to: 'supplier_products_search#search'
      post 'supplier_products_search/grouped', to: 'supplier_products_search#grouped_search'
      get 'supplier_products_search/filters', to: 'supplier_products_search#filters'
      get 'supplier_products_search/product/:id', to: 'supplier_products_search#product_details'
      get 'supplier_products_search/available_sizes/:diameter', to: 'supplier_products_search#available_sizes_by_diameter'
      
      # Чат-консультант по шинам
      post 'tire_chat/message', to: 'tire_chat#message'
      get 'tire_chat/stream', to: 'tire_chat#stream'
      post 'tire_chat/reset', to: 'tire_chat#reset'
      get 'tire_chat/status', to: 'tire_chat#status'
      
      # Управление поставщиками
      resources :suppliers do
        member do
          get :products
          get :statistics
          get :price_versions
          post :admin_upload_price
          patch :regenerate_api_key
        end
        collection do
          post :upload_price
          get 'products/all', action: :all_products
        end
      end
      
      # Настройки системы
      get 'settings', to: 'settings#show'
      patch 'settings', to: 'settings#update'
      
      # Диагностика настроек системы
      get 'settings_diagnostics', to: 'settings_diagnostics#index'
      
      # Поиск шин по автомобилю
      post 'car_tire_search/search', to: 'car_tire_search#search'
      post 'car_tire_search/resolve_brand', to: 'car_tire_search#resolve_brand'
      post 'car_tire_search/resolve_model', to: 'car_tire_search#resolve_model'
      
      # Система уведомлений
      resources :email_templates do
        member do
          patch :toggle_status
          post :preview
          post :test_send
          post 'add_custom_variable'
          delete 'remove_custom_variable/:custom_variable_id', action: 'remove_custom_variable'
        end
        collection do
          get 'template_types'
        end
      end
      
      # Тестирование email
      namespace :email_test do
        post 'send_template'
        post 'simple'
        get 'smtp_config'
      end

      resources :custom_variables do
        collection do
          get 'categories'
          get 'by_category'
        end
      end
      
      # Telegram интеграция
      post 'telegram_webhook', to: 'telegram_webhook#webhook'
      get 'telegram_webhook', to: 'telegram_webhook#show_config'
      
      # Управление настройками Telegram
      resource :telegram_settings, only: [:show, :update] do
        member do
          post :test_connection
          post :test_message
          post :get_chat_id
          post :set_webhook
          post :force_webhook_update
          post :generate_ngrok_webhook
          get :webhook_info
        end
      end
      
      # Управление настройками Push уведомлений
      resource :push_settings, only: [:show, :update] do
        member do
          post :test_notification
          get :subscriptions
        end
      end
      
      # Управление настройками Email
      resource :email_settings, only: [:show, :update] do
        member do
          post :test_email
        end
      end
      
      # Управление настройками Google OAuth
      resource :google_oauth_settings, only: [:show, :update] do
        member do
          post :test_connection
          get :authorization_url
        end
      end
      
      # Управление настройками каналов уведомлений
      resources :notification_channel_settings, only: [:index, :show, :update] do
        collection do
          post :bulk_update
          get :statistics
        end
      end
      
      # Push подписки пользователей
      resources :push_subscriptions do
        member do
          post :activate
          post :deactivate
          post :test_notification
        end
        collection do
          delete :destroy_by_endpoint
        end
      end
      
      # Статистика уведомлений (только для админов)
      resources :notification_statistics, only: [] do
        collection do
          get :overview
          get :daily
          get :hourly
          get :templates
          get :recipients
          get :failures
          get :performance
        end
      end
      
      resources :telegram_subscriptions do
        member do
          post 'toggle_status'
          post 'test_notification'
        end
      end
      
      resources :telegram_notifications do
        member do
          post 'retry'
        end
        collection do
          get 'stats'
        end
      end
      
      # Управление локалью
      get 'locale', to: 'locale#show'
      put 'locale', to: 'locale#update'
      
      # ✅ Универсальная аутентификация (email ИЛИ телефон)
      post 'auth/login', to: 'auth#login'
      post 'auth/logout', to: 'auth#logout'
      get 'auth/me', to: 'auth#me'
      post 'auth/refresh', to: 'auth#refresh'
      put 'auth/profile', to: 'auth#update_profile'
      
      # ✅ Восстановление пароля
      post 'password/forgot', to: 'passwords#forgot'
      post 'password/reset', to: 'passwords#reset'
      get 'password/verify_token/:token', to: 'passwords#verify_token'
      
      # Автомобили текущего клиента
      get 'auth/me/cars', to: 'auth#my_cars'
      post 'auth/me/cars', to: 'auth#create_car'
      patch 'auth/me/cars/:id', to: 'auth#update_car'
      delete 'auth/me/cars/:id', to: 'auth#delete_car'
      
      # ✅ НОВЫЕ МАРШРУТЫ: Избранные сервисные точки текущего пользователя
      get 'auth/me/favorite_points', to: 'auth#my_favorite_points'
      get 'auth/me/favorite_points/by_category', to: 'auth#my_favorite_points_by_category'
      post 'auth/me/favorite_points', to: 'auth#add_to_my_favorites'
      delete 'auth/me/favorite_points/:id', to: 'auth#remove_from_my_favorites'
      get 'auth/me/favorite_points/check/:service_point_id', to: 'auth#check_is_favorite'
      
      # Клиентский API доступности (упрощенный)
      get 'availability/:service_point_id/:date', to: 'availability#client_available_times'
      post 'bookings/check_availability', to: 'availability#client_check_availability'
      
      # API доступности с поддержкой категорий
      post 'availability/check_with_category', to: 'availability#check_with_category'
      get 'availability/slots_for_category', to: 'availability#slots_for_category'
      
      # Клиентский API поиска сервисных точек  
      get 'service_points/search', to: 'service_points#client_search'
      
      # Динамические списки регионов и городов с учетом фильтров
      get 'service_points/regions', to: 'service_points#regions_with_service_points'
      get 'service_points/cities', to: 'service_points#cities_with_service_points'
      
      # Клиентский API записей (включая гостевые записи)
      resources :client_bookings, only: [:create, :show, :update, :destroy] do
        member do
          post :cancel, to: 'client_bookings#cancel'
          post :reschedule, to: 'client_bookings#reschedule'
          post :assign_to_client, to: 'client_bookings#assign_to_client'
        end
        collection do
          post :check_availability_for_booking, to: 'client_bookings#check_availability_for_booking'
        end
      end
      
      # API корзины и заказов шин
      resources :tire_carts, only: [:index, :show, :destroy] do
        member do
          post 'items', to: 'tire_carts#add_item'
          put 'items/:item_id', to: 'tire_carts#update_item'
          delete 'items/:item_id', to: 'tire_carts#remove_item'
          delete 'clear', to: 'tire_carts#clear'
        end
      end
      
      # Новая единая корзина
      resource :unified_tire_cart, only: [:show] do
        post 'add_item'
        put 'update_item/:item_id', to: 'unified_tire_carts#update_item'
        delete 'remove_item/:item_id', to: 'unified_tire_carts#remove_item'
        delete 'clear'
        post 'create_orders'
        post 'create_supplier_order'
      end
      
      resources :tire_orders, only: [:index, :show, :create] do
        member do
          patch :cancel
          patch :archive
        end
        collection do
          get :all, to: 'tire_orders#index_all'  # Только для админов
          patch ':id/confirm', to: 'tire_orders#confirm'
          patch ':id/start_processing', to: 'tire_orders#start_processing'
          patch ':id/complete', to: 'tire_orders#complete'
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
          patch :suspend
          patch :unsuspend
          get :suspension_info
        end
        collection do
          get :check_exists
        end
      end
      
      # Администраторы
      resources :administrators, only: [:index, :show, :create, :update, :destroy]
      
      # Заявки партнеров
      resources :partner_applications, only: [:index, :show, :create, :update, :destroy] do
        member do
          patch :update_status
        end
        collection do
          get :stats
        end
      end
      
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
        resources :operators, only: [:index, :create] do
          # Управление привязками операторов к сервисным точкам
          resources :service_points, controller: 'operator_service_points', only: [:index, :create] do
            collection do
              post :bulk_assign
            end
          end
        end
        
        # Заказы партнера
        resources :orders, controller: 'partner_orders', only: [:index, :show] do
          member do
            post 'mark_as_ready'
            post 'mark_as_delivered'
            post 'cancel'
            post 'add_note'
          end
          collection do
            get 'stats'
            get 'export'
          end
        end
        
        # Создание тестовых данных для партнера
        collection do
          post 'create_test', to: 'partners#create_test'
        end
        
        # Активация/деактивация партнера
        member do
          patch 'toggle_active', to: 'partners#toggle_active'
          get 'related_data', to: 'partners#related_data'
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
        resources :seasonal_schedules, only: [:index, :show, :create, :update, :destroy] do
          collection do
            get 'active_for_date', to: 'seasonal_schedules#active_for_date'
            get 'active_for_period', to: 'seasonal_schedules#active_for_period'
          end
        end
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
        resources :favorite_points, only: [:index, :show, :create, :destroy], controller: 'client_favorite_points' do
          collection do
            get 'by_category', to: 'client_favorite_points#by_category'
            get 'check_availability', to: 'client_favorite_points#check_availability'
          end
        end
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
      
      # Справочники шин
      resources :countries, only: [:index, :show, :create, :update, :destroy] do
        member do
          patch :toggle_status
        end
      end
      
      resources :tire_brands, only: [:index, :show, :create, :update, :destroy] do
        member do
          patch :toggle_status
        end
        collection do
          get :top_brands
        end
      end
      
      resources :tire_models, only: [:index, :show, :create, :update, :destroy] do
        member do
          patch :toggle_status
        end
        collection do
          get :seasons
          get 'by_brand/:brand_id', action: :by_brand, as: :by_brand
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
      
      # Заказы интернет-магазинов  
      resources :orders do
        member do
          post 'mark_as_ready', to: 'orders#mark_as_ready'
          post 'mark_as_delivered', to: 'orders#mark_as_delivered'  
          post 'cancel', to: 'orders#cancel'
        end
      end

      # Бронирования
      resources :bookings, only: [:index, :show, :create, :update, :destroy] do
        member do
          patch 'status', to: 'bookings#update_status'
          post 'confirm', to: 'bookings#confirm'
          post 'cancel', to: 'bookings#cancel'
          post 'complete', to: 'bookings#complete'
          post 'no_show', to: 'bookings#no_show'
        end
      end

      # Конфликты бронирований
      resources :booking_conflicts, only: [:index, :show] do
        member do
          post 'resolve', to: 'booking_conflicts#resolve'
          post 'ignore', to: 'booking_conflicts#ignore'
        end
        collection do
          get 'statistics', to: 'booking_conflicts#statistics'
          post 'analyze', to: 'booking_conflicts#analyze'
          post 'preview', to: 'booking_conflicts#preview'
          post 'preview_with_form_data', to: 'booking_conflicts#preview_with_form_data'
          post 'bulk_resolve', to: 'booking_conflicts#bulk_resolve'
        end
      end

      # Статусы бронирований
      resources :booking_statuses, only: [:index]
      
      # Расписание
      get 'schedule/:service_point_id/:date', to: 'schedule#day', as: 'schedule_day'
      get 'schedule/:service_point_id/:from_date/:to_date', to: 'schedule#period', as: 'schedule_period'
      post 'schedule/generate_for_date/:service_point_id/:date', to: 'schedule#generate_for_date', as: 'generate_schedule_for_date'
      post 'schedule/generate_for_period/:service_point_id/:from_date/:to_date', to: 'schedule#generate_for_period', as: 'generate_schedule_for_period'
      
      # Уведомления
      resources :notifications, only: [:index, :show, :create, :update, :destroy] do
        collection do
          post 'mark_all_as_read'
          delete 'destroy_all'
          get 'stats'
        end
      end
      
      # Системные логи (только для администраторов)
      resources :system_logs, only: [:index, :show] do
        collection do
          get :stats
          get :export
          get :search_autocomplete
          get :suspicious_activity
          get 'user_timeline/:user_id', action: :user_timeline, as: :user_timeline
          post :manual_log
        end
        
        member do
          get 'resource_history/:resource_type/:resource_id', action: :resource_history, as: :resource_history
        end
      end
      
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
        resources :orders
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

      resources :operators, only: [:index, :update, :destroy] do
        # Получение назначений оператора к сервисным точкам
        resources :service_points, controller: 'operator_service_points', only: [:index, :create] do
          collection do
            post :bulk_assign
          end
        end
      end

      # Прямые маршруты для управления привязками операторов
      resources :operator_service_points, only: [:show, :update, :destroy]

      # Аудит логи
      resources :audit_logs, only: [:index, :show, :create] do
        collection do
          get :stats
          get :export
          get :search_autocomplete
          get :suspicious_activity
          get 'user_timeline/:user_id', action: :user_timeline, as: :user_timeline
          post :manual_log
        end
        
        member do
          get 'resource_history/:resource_type/:resource_id', action: :resource_history, as: :resource_history
        end
      end

      # Управление шаблонами уведомлений
      resources :notification_templates, only: [:index, :show, :create, :update, :destroy]
      
      # SEO метатеги
      resources :seo_metatags do
        collection do
          post :create_defaults
          get :analytics
          get 'for_page/:page_type', action: :for_page, as: :for_page
        end
      end
      
      # Нормализация данных шин
      namespace :normalization do
        get :stats
        get :unprocessed
        post :run_normalization
        get :top_unprocessed
      end
      
          # Админские маршруты
    namespace :admin do
      # Управление данными поиска шин
      get 'tire_data/versions', to: 'tire_data#versions'
      get 'tire_data/current_version', to: 'tire_data#current_version'
      post 'tire_data/update', to: 'tire_data#update'
      delete 'tire_data/rollback', to: 'tire_data#rollback'
      get 'tire_data/statistics', to: 'tire_data#statistics'
      post 'tire_data/cleanup', to: 'tire_data#cleanup'
      
      # Системные настройки
      resources :system_settings, param: :key, except: [:new, :edit] do
        collection do
          post :reset_defaults
          get :categories
          post :test_connection
          post :sync_llm_settings
        end
      end

      # Управление данными шин
      scope :tire_data do
        get :status, to: 'tire_data#status'
        post :validate_files, to: 'tire_data#validate_files'
        post :import, to: 'tire_data#import'
        delete 'version/:version', to: 'tire_data#delete_version'
        post 'rollback/:version', to: 'tire_data#rollback'
        post :clean_models, to: 'tire_data#clean_models'
      end
    end
    end
  end
end
