# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Контроллер для управления данными шин
      class TireDataController < AdminController
        # Аутентификация и проверка прав админа уже выполняется в AdminController

        # GET /api/v1/admin/tire_data/status
        def status
          begin
            stats = {
              configurations_count: CarTireConfiguration.count,
              active_configurations: CarTireConfiguration.where(is_active: true).count,
              current_version: TireDataVersion.where(is_active: true).first&.version || 'Нет данных',
              last_update: TireDataVersion.where(is_active: true).first&.imported_at&.strftime('%d.%m.%Y %H:%M') || 'Никогда',
              available_versions: TireDataVersion.order(imported_at: :desc).limit(5).pluck(:version, :imported_at).map { |v, t| { version: v, imported_at: t.strftime('%d.%m.%Y %H:%M') } }
            }
            
            render json: { status: 'success', data: stats }, status: :ok
          rescue => e
            Rails.logger.error "Ошибка получения статуса данных шин: #{e.message}"
            render json: { status: 'error', message: e.message }, status: :internal_server_error
          end
        end

        # POST /api/v1/admin/tire_data/validate_files
        def validate_files
          csv_path = params[:csv_path]
          
          unless csv_path.present?
            return render json: { status: 'error', message: 'Не указан путь к CSV файлам' }, status: :bad_request
          end

          unless Dir.exist?(csv_path)
            return render json: { status: 'error', message: "Папка не найдена: #{csv_path}" }, status: :bad_request
          end

          begin
            validator = TireDataValidator.new(csv_path)
            validation_result = validator.validate_all_files
            
            render json: { 
              status: validation_result[:valid] ? 'success' : 'warning',
              data: validation_result
            }, status: :ok
          rescue => e
            Rails.logger.error "Ошибка валидации файлов: #{e.message}"
            render json: { status: 'error', message: e.message }, status: :internal_server_error
          end
        end

        # POST /api/v1/admin/tire_data/import
        def import
          # Читаем данные из JSON тела запроса
          request_body = JSON.parse(request.body.read) rescue {}
          
          csv_path = request_body['csv_path'] || params[:csv_path]
          version = request_body['version'] || params[:version] || "auto_#{Time.current.strftime('%Y%m%d_%H%M%S')}"
          # Проверяем force_reload в продакшене
          force_reload = request_body['force_reload'] || (params[:force_reload] == 'true')
          if force_reload && Rails.env.production?
            return render json: { 
              status: 'error', 
              message: '🚨 ОПАСНОСТЬ: Полная очистка данных запрещена в продакшене! Используйте обычное обновление без force_reload.',
              code: 'force_reload_forbidden_in_production'
            }, status: :forbidden
          end
          
          options = {
            skip_invalid_rows: request_body['skip_invalid_rows'] || (params[:skip_invalid_rows] == 'true'),
            fix_suspicious_sizes: request_body['fix_suspicious_sizes'] || (params[:fix_suspicious_sizes] == 'true'),
            encoding_fallback: request_body['encoding_fallback'] || params[:encoding_fallback] || 'utf-8',
            force_reload: force_reload,
            clear_only: request_body['clear_only'] || (params[:clear_only] == 'true')
          }
          
          # Для clear_only путь к CSV не обязателен
          unless csv_path.present? || options[:clear_only]
            return render json: { status: 'error', message: 'Не указан путь к CSV файлам' }, status: :bad_request
          end

          # Проверяем существование папки только если не только очистка
          unless options[:clear_only] || Dir.exist?(csv_path)
            return render json: { status: 'error', message: "Папка не найдена: #{csv_path}" }, status: :bad_request
          end

          begin
            processor = TireData::Processor.new(csv_path, version, options)
            result = processor.process_and_update

            if result[:success]
              render json: { 
                status: 'success', 
                message: 'Данные успешно импортированы',
                data: {
                  version: result[:version],
                  statistics: result[:statistics],
                  warnings: result[:warnings] || [],
                  skipped_rows: result[:skipped_rows] || 0
                }
              }, status: :ok
            else
              render json: { 
                status: 'error', 
                message: result[:message],
                details: result[:details] || {}
              }, status: :unprocessable_entity
            end
          rescue => e
            Rails.logger.error "Ошибка импорта данных: #{e.message}"
            render json: { status: 'error', message: e.message }, status: :internal_server_error
          end
        end

        # DELETE /api/v1/admin/tire_data/version/:version
        def delete_version
          version = params[:version]
          
          unless version.present?
            return render json: { status: 'error', message: 'Не указана версия для удаления' }, status: :bad_request
          end

          begin
            data_version = TireDataVersion.find_by(version: version)
            
            unless data_version
              return render json: { status: 'error', message: "Версия #{version} не найдена" }, status: :not_found
            end

            if data_version.is_active?
              return render json: { status: 'error', message: 'Нельзя удалить активную версию данных' }, status: :unprocessable_entity
            end

            # Удаляем конфигурации этой версии
            CarTireConfiguration.where(data_version: version).destroy_all
            data_version.destroy

            render json: { 
              status: 'success', 
              message: "Версия #{version} успешно удалена" 
            }, status: :ok
          rescue => e
            Rails.logger.error "Ошибка удаления версии: #{e.message}"
            render json: { status: 'error', message: e.message }, status: :internal_server_error
          end
        end

        # POST /api/v1/admin/tire_data/rollback/:version
        def rollback
          target_version = params[:version]
          
          unless target_version.present?
            return render json: { status: 'error', message: 'Не указана версия для отката' }, status: :bad_request
          end

          begin
            target_data_version = TireDataVersion.find_by(version: target_version)
            
            unless target_data_version
              return render json: { status: 'error', message: "Версия #{target_version} не найдена" }, status: :not_found
            end

            # Деактивируем текущую версию
            TireDataVersion.where(is_active: true).update_all(is_active: false)
            
            # Активируем целевую версию
            target_data_version.update!(is_active: true)
            
            # Деактивируем все конфигурации
            CarTireConfiguration.update_all(is_active: false)
            
            # Активируем конфигурации целевой версии
            CarTireConfiguration.where(data_version: target_version).update_all(is_active: true)

            render json: { 
              status: 'success', 
              message: "Успешно выполнен откат к версии #{target_version}" 
            }, status: :ok
          rescue => e
            Rails.logger.error "Ошибка отката версии: #{e.message}"
            render json: { status: 'error', message: e.message }, status: :internal_server_error
          end
        end

        # POST /api/v1/admin/tire_data/clean_models
        def clean_models
          force_mode = params[:force] == 'true' || params[:force] == true
          
          begin
            # Получаем все названия брендов
            brand_names = CarBrand.pluck(:name).map(&:strip).uniq
            
            # Находим модели, которые совпадают с названиями брендов
            problematic_models = CarModel.joins(:brand).where(name: brand_names)
            
            if problematic_models.count == 0
              return render json: { 
                status: 'success', 
                message: 'Проблемных моделей не найдено',
                data: { removed_count: 0, total_problematic: 0 }
              }, status: :ok
            end
            
            # Список явно проблемных случаев
            problematic_cases = {
              'Mitsubishi' => ['Jeep'],
              'Nissan' => ['Datsun', 'Infiniti'], 
              'Hyundai' => ['Genesis', 'Kia'],
              'Jiangling' => ['Landwind'],
              'Toyota' => ['Lexus', 'Scion'],
              'Volkswagen' => ['Audi', 'Bentley', 'Bugatti', 'Lamborghini', 'Porsche', 'Seat', 'Skoda'],
              'General Motors' => ['Buick', 'Cadillac', 'Chevrolet', 'GMC', 'Opel', 'Vauxhall'],
              'Ford' => ['Lincoln', 'Mercury'],
              'Chrysler' => ['Dodge', 'Jeep', 'Ram'],
              'BMW' => ['MINI', 'Rolls-Royce'],
              'Tata' => ['Jaguar', 'Land Rover'],
              'Geely' => ['Volvo', 'Lotus', 'Polestar']
            }
            
            valid_coincidences = ['Jetta', 'ZX', 'Tank', 'Victory', 'Emgrand', 'Gratour']
            
            confirmed_problematic = []
            potentially_valid = []
            
            problematic_models.includes(:brand).each do |model|
              brand_name = model.brand.name
              model_name = model.name
              
              is_clearly_problematic = false
              
              # Проверяем явные случаи
              if problematic_cases[brand_name]&.include?(model_name)
                is_clearly_problematic = true
              elsif brand_names.include?(model_name) && brand_name != model_name && !valid_coincidences.include?(model_name)
                is_clearly_problematic = true
              end
              
              if is_clearly_problematic
                confirmed_problematic << model
              else
                potentially_valid << model
              end
            end
            
            removed_count = 0
            removed_models = []
            
            # Удаляем явно проблемные
            confirmed_problematic.each do |model|
              removed_models << { brand: model.brand.name, model: model.name, reason: 'явно проблемная' }
              model.destroy
              removed_count += 1
            end
            
            # Удаляем спорные в принудительном режиме
            if force_mode
              potentially_valid.each do |model|
                removed_models << { brand: model.brand.name, model: model.name, reason: 'спорная (принудительно)' }
                model.destroy
                removed_count += 1
              end
            end
            
            render json: {
              status: 'success',
              message: "Очистка завершена. Удалено #{removed_count} моделей",
              data: {
                removed_count: removed_count,
                total_problematic: problematic_models.count,
                confirmed_problematic: confirmed_problematic.count,
                potentially_valid: potentially_valid.count,
                force_mode: force_mode,
                removed_models: removed_models,
                remaining_suspicious: force_mode ? [] : potentially_valid.map { |m| { brand: m.brand.name, model: m.name } }
              }
            }, status: :ok
            
          rescue => e
            Rails.logger.error "Ошибка очистки моделей: #{e.message}"
            render json: { status: 'error', message: e.message }, status: :internal_server_error
          end
        end
      end
    end
  end
end