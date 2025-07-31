# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Контроллер для управления системными настройками через админку
      class SystemSettingsController < AdminController
        # Аутентификация и проверка прав админа уже выполняется в AdminController

        # GET /api/v1/admin/system_settings
        def index
          settings = get_all_settings
          render json: { settings: settings }, status: :ok
        end

        # GET /api/v1/admin/system_settings/:key
        def show
          key = params[:key]
          setting = get_setting(key)
          
          if setting
            render json: { setting: setting }, status: :ok
          else
            render json: { error: "Настройка '#{key}' не найдена" }, status: :not_found
          end
        end

        # PUT /api/v1/admin/system_settings/:key
        def update
          key = params[:key]
          value = params[:value]
          description = params[:description]
          
          if update_setting(key, value, description)
            render json: { 
              message: "Настройка '#{key}' обновлена", 
              setting: get_setting(key) 
            }, status: :ok
          else
            render json: { error: "Ошибка обновления настройки" }, status: :unprocessable_entity
          end
        end

        # POST /api/v1/admin/system_settings
        def create
          key = params[:key]
          value = params[:value]
          description = params[:description]
          category = params[:category] || 'general'
          
          if create_setting(key, value, description, category)
            render json: { 
              message: "Настройка '#{key}' создана", 
              setting: get_setting(key) 
            }, status: :created
          else
            render json: { error: "Ошибка создания настройки" }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/admin/system_settings/:key
        def destroy
          key = params[:key]
          
          if delete_setting(key)
            render json: { message: "Настройка '#{key}' удалена" }, status: :ok
          else
            render json: { error: "Ошибка удаления настройки" }, status: :unprocessable_entity
          end
        end

        # POST /api/v1/admin/system_settings/reset_defaults
        def reset_defaults
          if reset_to_defaults
            render json: { 
              message: "Настройки сброшены к значениям по умолчанию",
              settings: get_all_settings
            }, status: :ok
          else
            render json: { error: "Ошибка сброса настроек" }, status: :unprocessable_entity
          end
        end

        # GET /api/v1/admin/system_settings/categories
        def categories
          categories = get_setting_categories
          render json: { categories: categories }, status: :ok
        end

        # POST /api/v1/admin/system_settings/test_connection
        def test_connection
          key = params[:key]
          value = params[:value]
          
          result = test_setting_connection(key, value)
          render json: result, status: :ok
        end

        private

        # Получить все настройки
        def get_all_settings
          begin
            settings = Rails.cache.fetch('system_settings:all', expires_in: 5.minutes) do
              default_settings.merge(custom_settings)
            end
          rescue => e
            Rails.logger.error "Error caching settings, using direct access: #{e.message}"
            settings = default_settings.merge(custom_settings)
          end
          
          # Группируем по категориям
          grouped = settings.group_by { |_, setting| setting[:category] }
          
          grouped.transform_values do |category_settings|
            category_settings.to_h
          end
        end

        # Получить конкретную настройку
        def get_setting(key)
          all_settings = get_all_settings.values.reduce(&:merge) || {}
          all_settings[key.to_s]
        end

        # Обновить настройку
        def update_setting(key, value, description = nil)
          begin
            # Валидируем значение
            validated_value = validate_setting_value(key, value)
            
            # Сохраняем в Redis
            setting_data = {
              key: key,
              value: validated_value,
              description: description || get_setting_description(key),
              category: get_setting_category(key),
              updated_at: Time.current.iso8601,
              updated_by: current_user&.email || 'system'
            }
            
            redis_key = "system_settings:custom:#{key}"
            Rails.cache.write(redis_key, setting_data.to_json, expires_in: nil)
            
            # Инвалидируем кеш
            Rails.cache.delete('system_settings:all')
            
            # Применяем настройку в runtime (если нужно)
            apply_runtime_setting(key, validated_value)
            
            Rails.logger.info "System setting updated: #{key} = #{validated_value}"
            true
          rescue => e
            Rails.logger.error "Error updating system setting #{key}: #{e.message}"
            false
          end
        end

        # Создать новую настройку
        def create_setting(key, value, description, category)
          return false if get_setting(key) # Уже существует
          
          update_setting(key, value, description)
        end

        # Удалить настройку
        def delete_setting(key)
          begin
            redis_key = "system_settings:custom:#{key}"
            Rails.cache.delete(redis_key)
            Rails.cache.delete('system_settings:all')
            
            Rails.logger.info "System setting deleted: #{key}"
            true
          rescue => e
            Rails.logger.error "Error deleting system setting #{key}: #{e.message}"
            false
          end
        end

        # Сброс к значениям по умолчанию
        def reset_to_defaults
          begin
            # Удаляем все кастомные настройки
            keys = Rails.cache.redis.keys('system_settings:custom:*')
            Rails.cache.redis.del(*keys) if keys.any?
            
            Rails.cache.delete('system_settings:all')
            
            Rails.logger.info "System settings reset to defaults"
            true
          rescue => e
            Rails.logger.error "Error resetting system settings: #{e.message}"
            false
          end
        end

        # Настройки по умолчанию
        def default_settings
          {
            # Поиск шин
            'tire_search_cache_ttl' => {
              key: 'tire_search_cache_ttl',
              value: '3600',
              description: 'Время кеширования результатов поиска шин (секунды)',
              category: 'tire_search',
              type: 'integer',
              min_value: 60,
              max_value: 86400,
              default: true
            },
            'tire_search_max_results' => {
              key: 'tire_search_max_results',
              value: '50',
              description: 'Максимальное количество результатов поиска',
              category: 'tire_search',
              type: 'integer',
              min_value: 10,
              max_value: 200,
              default: true
            },
            'tire_search_enable_llm' => {
              key: 'tire_search_enable_llm',
              value: 'false',
              description: 'Включить LLM для обработки сложных запросов',
              category: 'tire_search',
              type: 'boolean',
              default: true
            },
            'openai_api_key' => {
              key: 'openai_api_key',
              value: '',
              description: 'API ключ OpenAI для LLM обработки запросов',
              category: 'integrations',
              type: 'password',
              required: false,
              default: true
            },
            'openai_model' => {
              key: 'openai_model',
              value: 'gpt-4o-mini',
              description: 'Модель OpenAI для обработки запросов',
              category: 'integrations',
              type: 'select',
              options: ['gpt-4o-mini', 'gpt-3.5-turbo', 'gpt-4'],
              default: true
            },
            
            # Redis
            'redis_url' => {
              key: 'redis_url',
              value: ENV['REDIS_URL'] || 'redis://localhost:6379/0',
              description: 'URL подключения к Redis',
              category: 'database',
              type: 'url',
              default: true
            },
            'redis_pool_size' => {
              key: 'redis_pool_size',
              value: '5',
              description: 'Размер пула соединений Redis',
              category: 'database',
              type: 'integer',
              min_value: 1,
              max_value: 50,
              default: true
            },
            
            # Аналитика
            'analytics_enabled' => {
              key: 'analytics_enabled',
              value: 'true',
              description: 'Включить сбор аналитики поиска',
              category: 'analytics',
              type: 'boolean',
              default: true
            },
            'analytics_retention_days' => {
              key: 'analytics_retention_days',
              value: '90',
              description: 'Срок хранения аналитических данных (дни)',
              category: 'analytics',
              type: 'integer',
              min_value: 7,
              max_value: 365,
              default: true
            },
            
            # Производительность
            'search_timeout_seconds' => {
              key: 'search_timeout_seconds',
              value: '30',
              description: 'Таймаут поиска (секунды)',
              category: 'performance',
              type: 'integer',
              min_value: 5,
              max_value: 120,
              default: true
            },
            'max_concurrent_searches' => {
              key: 'max_concurrent_searches',
              value: '100',
              description: 'Максимальное количество одновременных поисков',
              category: 'performance',
              type: 'integer',
              min_value: 10,
              max_value: 1000,
              default: true
            }
          }
        end

        # Кастомные настройки из Redis
        def custom_settings
          settings = {}
          
          begin
            # Проверяем, доступен ли Redis
            if Rails.cache.respond_to?(:redis) && Rails.cache.redis
              keys = Rails.cache.redis.keys('system_settings:custom:*')
              
              keys.each do |redis_key|
                setting_json = Rails.cache.redis.get(redis_key)
                next unless setting_json
                
                setting_data = JSON.parse(setting_json, symbolize_names: true)
                settings[setting_data[:key]] = setting_data
              end
            else
              Rails.logger.warn "Redis не доступен, используем пустые кастомные настройки"
            end
          rescue => e
            Rails.logger.error "Error loading custom settings: #{e.message}"
          end
          
          settings
        end

        # Валидация значения настройки
        def validate_setting_value(key, value)
          setting_config = default_settings[key]
          return value unless setting_config

          case setting_config[:type]
          when 'integer'
            int_value = value.to_i
            min_val = setting_config[:min_value]
            max_val = setting_config[:max_value]
            
            if min_val && int_value < min_val
              raise "Значение должно быть не менее #{min_val}"
            end
            
            if max_val && int_value > max_val
              raise "Значение должно быть не более #{max_val}"
            end
            
            int_value.to_s
          when 'boolean'
            ['true', '1', 'yes', 'on'].include?(value.to_s.downcase) ? 'true' : 'false'
          when 'url'
            uri = URI.parse(value.to_s)
            raise "Некорректный URL" unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS) || uri.scheme == 'redis'
            value.to_s
          when 'select'
            options = setting_config[:options] || []
            raise "Недопустимое значение. Доступны: #{options.join(', ')}" unless options.include?(value.to_s)
            value.to_s
          else
            value.to_s
          end
        end

        # Применение настройки в runtime
        def apply_runtime_setting(key, value)
          case key
          when 'redis_url'
            # Для Redis URL нужен перезапуск приложения
            Rails.logger.warn "Redis URL updated. Application restart required."
          when 'tire_search_cache_ttl'
            # Обновляем TTL в TireSearchService если он уже загружен
            if defined?(TireSearchService)
              TireSearchService.instance_variable_set(:@cache_ttl, value.to_i)
            end
          end
        end

        # Получить категории настроек
        def get_setting_categories
          {
            'tire_search' => {
              name: 'Поиск шин',
              description: 'Настройки системы поиска шин',
              icon: 'search'
            },
            'integrations' => {
              name: 'Интеграции',
              description: 'Внешние сервисы и API',
              icon: 'link'
            },
            'database' => {
              name: 'База данных',
              description: 'Настройки подключения к БД',
              icon: 'storage'
            },
            'analytics' => {
              name: 'Аналитика',
              description: 'Сбор и хранение аналитических данных',
              icon: 'analytics'
            },
            'performance' => {
              name: 'Производительность',
              description: 'Настройки производительности системы',
              icon: 'speed'
            },
            'general' => {
              name: 'Общие',
              description: 'Общие настройки системы',
              icon: 'settings'
            }
          }
        end

        # Тестирование подключения
        def test_setting_connection(key, value)
          case key
          when 'redis_url'
            test_redis_connection(value)
          when 'openai_api_key'
            test_openai_connection(value)
          else
            { success: false, message: "Тестирование для '#{key}' не поддерживается" }
          end
        end

        # Тест Redis подключения
        def test_redis_connection(url)
          begin
            redis = Redis.new(url: url, timeout: 5)
            result = redis.ping
            redis.quit
            
            if result == 'PONG'
              { success: true, message: 'Подключение к Redis успешно' }
            else
              { success: false, message: 'Неожиданный ответ от Redis' }
            end
          rescue => e
            { success: false, message: "Ошибка подключения к Redis: #{e.message}" }
          end
        end

        # Тест OpenAI подключения
        def test_openai_connection(api_key)
          return { success: false, message: 'API ключ не указан' } if api_key.blank?
          
          begin
            require 'net/http'
            require 'json'
            
            uri = URI('https://api.openai.com/v1/models')
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            http.read_timeout = 10
            
            request = Net::HTTP::Get.new(uri)
            request['Authorization'] = "Bearer #{api_key}"
            
            response = http.request(request)
            
            if response.code == '200'
              { success: true, message: 'Подключение к OpenAI API успешно' }
            else
              { success: false, message: "Ошибка API: #{response.code} #{response.message}" }
            end
          rescue => e
            { success: false, message: "Ошибка подключения к OpenAI: #{e.message}" }
          end
        end

        # Получить описание настройки
        def get_setting_description(key)
          default_settings[key]&.dig(:description) || 'Пользовательская настройка'
        end

        # Получить категорию настройки
        def get_setting_category(key)
          default_settings[key]&.dig(:category) || 'general'
        end
      end
    end
  end
end