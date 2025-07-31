module Api
  module V1
    module Admin
      class TireDataController < AdminController
        before_action :ensure_admin!

        # GET /api/v1/admin/tire_data/versions
        # Получение списка всех версий данных поиска шин
        def versions
          versions = TireDataVersion.order(imported_at: :desc)
                                   .limit(params[:limit]&.to_i || 50)
                                   .offset(params[:offset]&.to_i || 0)
          
          total_count = TireDataVersion.count
          
          render json: {
            versions: versions.map do |version|
              {
                id: version.id,
                version: version.version,
                source_description: version.source_description,
                imported_at: version.imported_at.iso8601,
                is_active: version.is_active,
                configurations_count: version.statistics&.dig('configurations_count') || 0,
                brands_count: version.statistics&.dig('brands_count') || 0,
                models_count: version.statistics&.dig('models_count') || 0,
                file_checksums: version.file_checksums || {}
              }
            end,
            pagination: {
              total: total_count,
              limit: params[:limit]&.to_i || 50,
              offset: params[:offset]&.to_i || 0,
              has_more: (params[:offset]&.to_i || 0) + (params[:limit]&.to_i || 50) < total_count
            }
          }
        rescue StandardError => e
          Rails.logger.error "TireDataController#versions error: #{e.message}"
          render json: { error: 'Ошибка получения списка версий' }, status: :internal_server_error
        end

        # GET /api/v1/admin/tire_data/current_version
        # Получение информации о текущей активной версии
        def current_version
          current = TireDataVersion.current
          
          if current
            render json: {
              version: {
                id: current.id,
                version: current.version,
                source_description: current.source_description,
                imported_at: current.imported_at.iso8601,
                is_active: current.is_active,
                configurations_count: current.statistics&.dig('configurations_count') || 0,
                brands_count: current.statistics&.dig('brands_count') || 0,
                models_count: current.statistics&.dig('models_count') || 0,
                file_checksums: current.file_checksums || {}
              }
            }
          else
            render json: { error: 'Активная версия данных не найдена' }, status: :not_found
          end
        rescue StandardError => e
          Rails.logger.error "TireDataController#current_version error: #{e.message}"
          render json: { error: 'Ошибка получения текущей версии' }, status: :internal_server_error
        end

        # POST /api/v1/admin/tire_data/update
        # Обновление данных поиска шин из CSV файлов
        def update
          # Параметры для обновления
          source_description = params[:source_description] || "Обновление данных #{Time.current.strftime('%Y-%m-%d %H:%M')}"
          csv_directory = params[:csv_directory] || Rails.root.join('tmp', 'tire_data_csv')
          
          # Проверяем наличие директории с CSV файлами
          unless Dir.exist?(csv_directory)
            render json: { 
              error: 'Директория с CSV файлами не найдена',
              expected_path: csv_directory 
            }, status: :bad_request
            return
          end

          # Запускаем обновление в фоновом режиме (или синхронно для тестирования)
          begin
            Rails.logger.info "Starting tire data update from #{csv_directory}"
            
            # Используем TireData::Processor для обработки данных
            processor = TireData::Processor.new(
              csv_directory: csv_directory,
              source_description: source_description
            )
            
            result = processor.process_all_files
            
            if result[:success]
              render json: {
                message: 'Данные успешно обновлены',
                version: result[:version],
                statistics: result[:statistics],
                imported_at: Time.current.iso8601
              }, status: :ok
            else
              render json: {
                error: 'Ошибка обновления данных',
                details: result[:errors] || []
              }, status: :unprocessable_entity
            end
            
          rescue StandardError => e
            Rails.logger.error "TireDataController#update error: #{e.message}"
            Rails.logger.error e.backtrace.join("\n")
            
            render json: { 
              error: 'Внутренняя ошибка при обновлении данных',
              details: e.message 
            }, status: :internal_server_error
          end
        end

        # DELETE /api/v1/admin/tire_data/rollback
        # Откат к предыдущей версии данных
        def rollback
          target_version = params[:version]
          
          if target_version.blank?
            render json: { error: 'Не указана версия для отката' }, status: :bad_request
            return
          end

          begin
            version_record = TireDataVersion.find_by(version: target_version)
            
            unless version_record
              render json: { error: "Версия #{target_version} не найдена" }, status: :not_found
              return
            end

            if version_record.is_active?
              render json: { error: "Версия #{target_version} уже активна" }, status: :bad_request
              return
            end

            Rails.logger.info "Starting rollback to version #{target_version}"
            
            # Выполняем откат
            ActiveRecord::Base.transaction do
              # Деактивируем текущую версию
              TireDataVersion.where(is_active: true).update_all(is_active: false)
              
              # Активируем целевую версию
              version_record.update!(is_active: true)
              
              # Обновляем флаги в car_tire_configurations
              CarTireConfiguration.where(is_active: true).update_all(is_active: false)
              CarTireConfiguration.where(data_version: target_version).update_all(is_active: true)
            end

            render json: {
              message: "Успешно выполнен откат к версии #{target_version}",
              version: target_version,
              activated_at: Time.current.iso8601,
              configurations_count: CarTireConfiguration.where(is_active: true).count
            }, status: :ok
            
          rescue StandardError => e
            Rails.logger.error "TireDataController#rollback error: #{e.message}"
            Rails.logger.error e.backtrace.join("\n")
            
            render json: { 
              error: 'Ошибка при откате к предыдущей версии',
              details: e.message 
            }, status: :internal_server_error
          end
        end

        # GET /api/v1/admin/tire_data/statistics
        # Получение детальной статистики по данным поиска шин
        def statistics
          begin
            current_version = TireDataVersion.current
            
            # Базовая статистика
            total_configurations = CarTireConfiguration.where(is_active: true, is_deprecated: false).count
            total_brands = CarTireConfiguration.joins(:brand)
                                               .where(is_active: true, is_deprecated: false)
                                               .distinct
                                               .count('car_brands.id')
            total_models = CarTireConfiguration.joins(:model)
                                               .where(is_active: true, is_deprecated: false)
                                               .distinct
                                               .count('car_models.id')
            
            # Статистика по годам
            year_stats = CarTireConfiguration.where(is_active: true, is_deprecated: false)
                                             .group('year_from, year_to')
                                             .count
            
            # Статистика по диаметрам (из JSONB)
            diameter_stats = ActiveRecord::Base.connection.execute(<<-SQL)
              SELECT 
                (jsonb_array_elements(tire_sizes)->>'diameter')::integer as diameter,
                COUNT(*) as count
              FROM car_tire_configurations 
              WHERE is_active = true AND is_deprecated = false
              GROUP BY (jsonb_array_elements(tire_sizes)->>'diameter')::integer
              ORDER BY diameter
            SQL
            
            # Топ-10 брендов по количеству конфигураций
            top_brands = CarTireConfiguration.joins(:brand)
                                             .where(is_active: true, is_deprecated: false)
                                             .group('car_brands.name')
                                             .count
                                             .sort_by { |_, count| -count }
                                             .first(10)
                                             .to_h

            render json: {
              current_version: current_version&.version,
              last_updated: current_version&.imported_at&.iso8601,
              totals: {
                configurations: total_configurations,
                brands: total_brands,
                models: total_models,
                versions: TireDataVersion.count
              },
              distributions: {
                years: year_stats,
                diameters: diameter_stats.map { |row| [row['diameter'], row['count']] }.to_h,
                top_brands: top_brands
              },
              data_quality: {
                active_configurations: CarTireConfiguration.where(is_active: true).count,
                deprecated_configurations: CarTireConfiguration.where(is_deprecated: true).count,
                configurations_with_aliases: CarTireConfiguration.where.not(search_aliases: []).count
              }
            }
            
          rescue StandardError => e
            Rails.logger.error "TireDataController#statistics error: #{e.message}"
            render json: { error: 'Ошибка получения статистики' }, status: :internal_server_error
          end
        end

        # POST /api/v1/admin/tire_data/cleanup
        # Очистка старых версий данных (оставляем последние N версий)
        def cleanup
          keep_versions = params[:keep_versions]&.to_i || 5
          
          if keep_versions < 2
            render json: { error: 'Необходимо сохранить минимум 2 версии' }, status: :bad_request
            return
          end

          begin
            # Получаем версии для удаления (все кроме последних N)
            versions_to_delete = TireDataVersion.order(imported_at: :desc)
                                                .offset(keep_versions)
                                                .pluck(:version)
            
            if versions_to_delete.empty?
              render json: { 
                message: "Нет версий для удаления (всего версий: #{TireDataVersion.count})",
                kept_versions: keep_versions
              }
              return
            end

            deleted_count = 0
            ActiveRecord::Base.transaction do
              # Удаляем конфигурации старых версий
              deleted_configs = CarTireConfiguration.where(data_version: versions_to_delete).delete_all
              
              # Удаляем записи версий
              deleted_count = TireDataVersion.where(version: versions_to_delete).delete_all
              
              Rails.logger.info "Cleaned up #{deleted_count} versions, #{deleted_configs} configurations"
            end

            render json: {
              message: "Очистка завершена успешно",
              deleted_versions: deleted_count,
              remaining_versions: TireDataVersion.count,
              deleted_version_list: versions_to_delete
            }
            
          rescue StandardError => e
            Rails.logger.error "TireDataController#cleanup error: #{e.message}"
            render json: { error: 'Ошибка при очистке старых версий' }, status: :internal_server_error
          end
        end

        private

        def ensure_admin!
          unless current_user&.admin?
            render json: { error: 'Доступ запрещен. Требуются права администратора.' }, status: :forbidden
          end
        end
      end
    end
  end
end