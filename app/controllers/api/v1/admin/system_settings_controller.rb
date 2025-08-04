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
          
          # Читаем данные из JSON body
          begin
            body_params = JSON.parse(request.body.read) if request.body.present?
            request.body.rewind if request.body.respond_to?(:rewind)
            
            value = body_params&.dig('value') || params[:value]
            description = body_params&.dig('description') || params[:description]
          rescue JSON::ParserError
            value = params[:value]
            description = params[:description]
          end
          
          Rails.logger.info "SystemSettings#update: key=#{key}, value=#{value}, description=#{description}"
          
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

        # POST /api/v1/admin/system_settings/sync_llm_settings
        def sync_llm_settings
          begin
            # Принудительная синхронизация настроек LLM
            Rails.logger.info "Starting LLM settings synchronization..."
            
            llm_settings = {
              'tire_search_enable_llm' => 'true',
              'openai_model' => 'gpt-4o-mini',
              'openai_max_tokens' => '500',
              'openai_temperature' => '0.1',
              'openai_timeout' => '30'
            }
            
            # Добавляем API ключ если он есть в параметрах
            if params[:openai_api_key].present?
              llm_settings['openai_api_key'] = params[:openai_api_key]
            end
            
            synced_count = 0
            llm_settings.each do |key, value|
              if force_sync_setting(key, value)
                synced_count += 1
                Rails.logger.info "Synced setting: #{key}"
              end
            end
            
            render json: { 
              message: "Синхронизировано #{synced_count} настроек LLM",
              synced_settings: llm_settings.keys,
              llm_available: OpenaiService.available?,
              llm_configured: OpenaiService.configured?
            }, status: :ok
            
          rescue => e
            Rails.logger.error "Error syncing LLM settings: #{e.message}"
            render json: { error: "Ошибка синхронизации настроек LLM: #{e.message}" }, status: :internal_server_error
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
          # Читаем данные из JSON body
          begin
            body_params = JSON.parse(request.body.read) if request.body.present?
            request.body.rewind if request.body.respond_to?(:rewind)
            
            key = body_params&.dig('key') || params[:key]
            value = body_params&.dig('value') || params[:value]
          rescue JSON::ParserError
            key = params[:key]
            value = params[:value]
          end
          
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
          # Сначала пытаемся найти в БД
          db_setting = SystemSetting.find_by(key: key.to_s)
          
          if db_setting
            setting = {
              key: db_setting.key,
              value: db_setting.value,
              description: db_setting.description,
              category: db_setting.category,
              type: db_setting.setting_type,
              default_value: db_setting.default_value,
              updated_at: db_setting.updated_at.iso8601,
              updated_by: db_setting.updated_by
            }
            Rails.logger.info "Found setting in DB: #{key} = #{setting[:value]} (category: #{setting[:category]})"
            return setting
          end
          
          # Fallback к кэшу/default настройкам
          all_settings = get_all_settings.values.reduce(&:merge) || {}
          setting = all_settings[key.to_s]
          Rails.logger.info "Getting setting from cache/defaults: #{key}: #{setting&.dig(:value)} (category: #{setting&.dig(:category)})"
          setting
        end

        # Принудительная синхронизация настройки (без валидации)
        def force_sync_setting(key, value)
          begin
            setting_data = {
              key: key,
              value: value.to_s,
              description: get_setting_description(key) || 'Auto-synced setting',
              category: get_setting_category(key),
              type: get_setting_type(key),
              updated_at: Time.current.iso8601,
              updated_by: 'sync_service'
            }
            
            redis_key = "system_settings:custom:#{key}"
            
            if Rails.cache.respond_to?(:redis) && Rails.cache.redis
              Rails.cache.redis.set(redis_key, setting_data.to_json)
            else
              Rails.cache.write(redis_key, setting_data.to_json, expires_in: nil)
            end
            
            # Инвалидируем кеш
            Rails.cache.delete('system_settings:all')
            
            true
          rescue => e
            Rails.logger.error "Error force syncing setting #{key}: #{e.message}"
            false
          end
        end

        # Обновить настройку
        def update_setting(key, value, description = nil)
          begin
            # Валидируем значение
            validated_value = validate_setting_value(key, value)
            
            # Сохраняем в базу данных (основной источник истины)
            setting = SystemSetting.find_or_initialize_by(key: key)
            setting.value = validated_value
            setting.description = description || setting.description || get_setting_description(key)
            setting.category = setting.category || get_setting_category(key)
            setting.setting_type = setting.setting_type || get_setting_type(key)
            setting.updated_by = current_user&.email || 'admin'
            setting.save!
            
            Rails.logger.info "System setting saved to DB: #{key} = #{validated_value}"
            
            # Дублируем в Redis для обратной совместимости и быстрого доступа
            setting_data = {
              key: key,
              value: validated_value,
              description: setting.description,
              category: setting.category,
              type: setting.setting_type,
              updated_at: setting.updated_at.iso8601,
              updated_by: setting.updated_by
            }
            
            redis_key = "system_settings:custom:#{key}"
            
            if Rails.cache.respond_to?(:redis) && Rails.cache.redis
              Rails.cache.redis.set(redis_key, setting_data.to_json)
            else
              Rails.cache.write(redis_key, setting_data.to_json, expires_in: nil)
            end
            
            # Инвалидируем кеш
            Rails.cache.delete('system_settings:all')
            
            # Применяем настройку в runtime (если нужно)
            apply_runtime_setting(key, validated_value)
            
            Rails.logger.info "System setting updated and cached: #{key} = #{validated_value}"
            
            true
          rescue => e
            Rails.logger.error "Error updating system setting #{key}: #{e.message}"
            Rails.logger.error e.backtrace.join("\n")
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
              options: ['gpt-4o-mini', 'gpt-3.5-turbo', 'gpt-4', 'gpt-4o'],
              default: true
            },
            'openai_max_tokens' => {
              key: 'openai_max_tokens',
              value: '500',
              description: 'Максимальное количество токенов для OpenAI ответа',
              category: 'integrations',
              type: 'integer',
              min_value: 100,
              max_value: 2000,
              default: true
            },
            'openai_temperature' => {
              key: 'openai_temperature',
              value: '0.1',
              description: 'Температура для OpenAI (0.0-1.0, чем меньше - тем точнее)',
              category: 'integrations',
              type: 'float',
              min_value: 0.0,
              max_value: 1.0,
              step: 0.1,
              default: true
            },
            'openai_timeout' => {
              key: 'openai_timeout',
              value: '30',
              description: 'Таймаут запроса к OpenAI (секунды)',
              category: 'integrations',
              type: 'integer',
              min_value: 5,
              max_value: 120,
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
              Rails.logger.info "Loading custom settings from Redis: found #{keys.length} keys"
              
              keys.each do |redis_key|
                setting_json = Rails.cache.redis.get(redis_key)
                next unless setting_json
                
                setting_data = JSON.parse(setting_json, symbolize_names: true)
                settings[setting_data[:key]] = setting_data
                Rails.logger.info "Loaded custom setting: #{setting_data[:key]} = #{setting_data[:value]}"
              end
            else
              Rails.logger.warn "Redis не доступен, используем Rails.cache fallback"
              
              # Fallback: ищем настройки через Rails.cache
              # Поскольку мы не можем получить список ключей из Rails.cache,
              # попробуем загрузить настройки для известных ключей
              default_settings.keys.each do |key|
                cache_key = "system_settings:custom:#{key}"
                setting_json = Rails.cache.read(cache_key)
                if setting_json
                  setting_data = JSON.parse(setting_json, symbolize_names: true)
                  settings[setting_data[:key]] = setting_data
                  Rails.logger.info "Loaded custom setting from Rails.cache: #{setting_data[:key]} = #{setting_data[:value]}"
                end
              end
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

        # Получить тип настройки
        def get_setting_type(key)
          default_settings[key]&.dig(:type) || 'string'
        end
      end
    end
  end
end