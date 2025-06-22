module Api
  module V1
    class PageContentsController < ApiController
      skip_before_action :authenticate_request, only: [:index, :show, :sections]
      before_action :set_current_user_if_authenticated, only: [:index]
      before_action :authorize_admin, except: [:index, :show, :sections]
      before_action :set_page_content, only: [:show, :update, :destroy, :toggle_active]

      # GET /api/v1/page_contents
      def index
        # Отладочная информация (только в режиме разработки)
        if Rails.env.development?
          Rails.logger.info "🔍 PageContents#index Debug:"
          Rails.logger.info "👤 Current User: #{current_user&.id} (#{current_user&.email})"
          Rails.logger.info "🔑 User Role: #{current_user&.role}"
          Rails.logger.info "👑 Is Admin?: #{current_user&.admin?}"
          Rails.logger.info "🌟 Is Super Admin?: #{current_user&.super_admin?}"
        end

        # Для публичного доступа показываем только активный контент
        # Админы и супер-админы могут видеть весь контент
        if current_user&.admin? || current_user&.super_admin?
          page_contents = PageContent.includes(image_attachment: :blob, gallery_images_attachments: :blob)
        else
          page_contents = PageContent.active.includes(image_attachment: :blob, gallery_images_attachments: :blob)
        end

        # Фильтрация по языку (по умолчанию украинский, но не для админов если не указан явно)
        if params[:language].present?
          page_contents = page_contents.by_language(params[:language])
        elsif !current_user&.admin? && !current_user&.super_admin?
          # Для обычных пользователей по умолчанию украинский
          page_contents = page_contents.by_language('uk')
        end
        # Для админов без указания языка показываем все языки

        # Фильтрация по секции
        if params[:section].present?
          page_contents = page_contents.by_section(params[:section])
        end

        # Фильтрация по типу контента
        if params[:content_type].present?
          page_contents = page_contents.by_content_type(params[:content_type])
        end

        # Поиск
        if params[:search].present?
          page_contents = page_contents.search(params[:search])
        end

        # Фильтрация по активности (только для админов)
        if (current_user&.admin? || current_user&.super_admin?) && params[:active].present?
          page_contents = page_contents.where(active: params[:active] == 'true')
        end

        # Сортировка
        page_contents = page_contents.ordered

        # Пагинация
        page = params[:page]&.to_i || 1
        per_page = params[:per_page]&.to_i || 20
        per_page = [per_page, 100].min # Максимум 100 записей за раз

        offset = (page - 1) * per_page
        total = page_contents.count
        page_contents = page_contents.offset(offset).limit(per_page)

        # Добавляем динамические данные для каждого элемента
        data = page_contents.map do |content|
          content_hash = content.as_json(
            include: {
              image_attachment: { include: :blob },
              gallery_images_attachments: { include: :blob }
            }
          )
          
          # Добавляем URL изображений
          content_hash['image_url'] = content.image_url
          content_hash['gallery_image_urls'] = content.gallery_image_urls
          
          # Добавляем метаданные
          content_hash['available_settings_fields'] = content.available_settings_fields
          content_hash['content_type_name'] = content.content_type_name
          content_hash['section_name'] = content.section_name
          content_hash['language_name'] = content.language_name
          
          # Добавляем динамические данные
          dynamic_data = content.dynamic_data
          if dynamic_data
            case content.content_type
            when 'service'
              content_hash['dynamic_data'] = dynamic_data.as_json(only: [:id, :name, :description, :category_id, :icon])
            when 'city'
              content_hash['dynamic_data'] = dynamic_data.as_json(only: [:id, :name, :region_id])
                                                         .map { |city| city.merge('service_points_count' => city['service_points_count'] || 0) }
            when 'article'
              content_hash['dynamic_data'] = dynamic_data.as_json(
                only: [:id, :title, :excerpt, :category, :reading_time, :published_at, :slug],
                include: { author: { only: [:id, :first_name, :last_name] } }
              )
            end
          end
          
          content_hash
        end

        render json: {
          data: data,
          meta: {
            current_page: page,
            per_page: per_page,
            total_pages: (total.to_f / per_page).ceil,
            total_count: total
          }
        }
      end

      # GET /api/v1/page_contents/:id
      def show
        content_hash = @page_content.as_json(
          include: {
            image_attachment: { include: :blob },
            gallery_images_attachments: { include: :blob }
          }
        )
        
        # Добавляем URL изображений
        content_hash['image_url'] = @page_content.image_url
        content_hash['gallery_image_urls'] = @page_content.gallery_image_urls
        
        # Добавляем метаданные
        content_hash['available_settings_fields'] = @page_content.available_settings_fields
        content_hash['content_type_name'] = @page_content.content_type_name
        content_hash['section_name'] = @page_content.section_name
        content_hash['language_name'] = @page_content.language_name
        
        # Добавляем динамические данные
        dynamic_data = @page_content.dynamic_data
        if dynamic_data
          case @page_content.content_type
          when 'service'
            content_hash['dynamic_data'] = dynamic_data.as_json(only: [:id, :name, :description, :category_id, :icon])
          when 'city'
            content_hash['dynamic_data'] = dynamic_data.as_json(only: [:id, :name, :region_id])
                                                       .map { |city| city.merge('service_points_count' => city['service_points_count'] || 0) }
          when 'article'
            content_hash['dynamic_data'] = dynamic_data.as_json(
              only: [:id, :title, :excerpt, :category_id, :reading_time, :published_at, :slug],
              include: { author: { only: [:id, :first_name, :last_name] } }
            )
          end
        end

        render json: content_hash
      end

      # POST /api/v1/page_contents
      def create
        @page_content = PageContent.new(page_content_params)
        
        if @page_content.save
          # Обработка загруженных файлов
          handle_file_uploads

          render json: serialize_page_content(@page_content), status: :created
        else
          render json: { 
            errors: @page_content.errors.full_messages,
            message: 'Не удалось создать контент. Проверьте правильность введенных данных.'
          }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/page_contents/:id
      def update
        if @page_content.update(page_content_params)
          # Обработка загруженных файлов
          handle_file_uploads

          render json: serialize_page_content(@page_content)
        else
          render json: { 
            errors: @page_content.errors.full_messages,
            message: 'Не удалось обновить контент. Проверьте правильность введенных данных.'
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/page_contents/:id
      def destroy
        @page_content.destroy!
        head :no_content
      rescue StandardError => e
        render json: { 
          error: e.message,
          message: 'Не удалось удалить контент.'
        }, status: :unprocessable_entity
      end

      # PATCH /api/v1/page_contents/:id/toggle_active
      def toggle_active
        @page_content.update!(active: !@page_content.active)
        render json: serialize_page_content(@page_content)
      rescue StandardError => e
        render json: { 
          error: e.message,
          message: 'Не удалось изменить статус контента.'
        }, status: :unprocessable_entity
      end

      # GET /api/v1/page_contents/sections
      def sections
        language = params[:language] || 'uk'
        
        sections = PageContent.by_language(language)
                             .group(:section)
                             .count
                             .map do |section, count|
          {
            key: section,
            name: get_section_name(section),
            count: count
          }
        end

        render json: { data: sections }
      end

      private

      def set_page_content
        @page_content = PageContent.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { 
          error: 'Контент не найден',
          message: 'Запрашиваемый контент не существует.'
        }, status: :not_found
      end

      def page_content_params
        params.require(:page_content).permit(
          :section,
          :content_type,
          :section, :content_type, :title, :content, :image_url, :position, :active,
          :image, gallery_images: [],
          settings: {}
        )
      end

      def authorize_admin
        unless @current_user&.admin?
          render json: { 
            error: 'У вас нет прав для выполнения этого действия',
            message: 'Для выполнения этого действия требуются права администратора.'
          }, status: :forbidden
        end
      end

      def handle_file_uploads
        # Обработка основного изображения
        if params[:page_content][:image].present?
          @page_content.image.attach(params[:page_content][:image])
        end

        # Обработка галереи изображений
        if params[:page_content][:gallery_images].present?
          @page_content.gallery_images.attach(params[:page_content][:gallery_images])
        end
      end

      def serialize_page_content(content)
        content_data = content.as_json
        
        content_data['image_url'] = content.image_url
        content_data['gallery_image_urls'] = content.gallery_image_urls
        content_data['settings'] = content.settings || {}
        content_data['available_settings_fields'] = content.available_settings_fields
        content_data['content_type_name'] = content.content_type_name
        content_data['section_name'] = content.section_name
        content_data['dynamic_data'] = content.dynamic_data

        content_data
      end

      # Получение городов с активными сервисными точками
      def get_cities_with_service_points
        City.joins(:service_points)
            .where(is_active: true, service_points: { is_active: true, work_status: 'working' })
            .includes(:region)
            .distinct
            .order(:name)
            .limit(10)
            .map do |city|
              {
                id: city.id,
                name: city.name,
                region_name: city.region.name,
                service_points_count: city.service_points.where(is_active: true, work_status: 'working').count
              }
            end
      end

      # Получение услуг по категории
      def get_services_by_category(category = nil)
        services = Service.where(is_active: true)
        services = services.joins(:service_category).where(service_categories: { name: category }) if category.present?
        
        services.includes(:service_category)
                .limit(8)
                .map do |service|
                  {
                    id: service.id,
                    name: service.name,
                    description: service.description,
                    category_id: service.category_id,
                    icon: service.icon || 'service'
                  }
                end
      rescue
        # Если таблица услуг не существует, возвращаем пустой массив
        []
      end

      # Получение статей из базы знаний
      def get_knowledge_base_articles(category = nil)
        articles = Article.where(status: 'published')
        articles = articles.where(category_id: category) if category.present?
        
        articles.includes(:author)
                .order(published_at: :desc)
                .limit(6)
                .map do |article|
                  {
                    id: article.id,
                    title: article.title,
                    excerpt: article.excerpt,
                    category_id: article.category_id,
                    reading_time: article.reading_time,
                    author: article.author&.first_name || 'Експерт',
                    published_at: article.published_at,
                    slug: article.slug
                  }
                end
      rescue
        # Если таблица статей не существует, возвращаем пустой массив
        []
      end

      # Устанавливаем current_user если токен валиден, но не требуем его
      def set_current_user_if_authenticated
        return unless request.headers['Authorization'].present?
        
        begin
          authenticate_request
        rescue => e
          # Игнорируем ошибки авторизации для публичного доступа
          Rails.logger.info "Public access: #{e.message}" if Rails.env.development?
        end
      end
    end
  end
end
