module Api
  module V1
    class ArticlesController < ApiController
      skip_before_action :authenticate_request, only: [:index, :show, :categories]
      before_action :authorize_admin, except: [:index, :show, :categories]
      before_action :set_article, only: [:show, :update, :destroy]
      
      # GET /api/v1/articles
      def index
        # Отладочная информация
        Rails.logger.info "ArticlesController#index: current_user=#{@current_user&.email}, admin=#{@current_user&.admin?}"
        
        articles = Article.includes(:author)
        
        # Для админов показываем все статьи, для обычных пользователей только опубликованные
        unless @current_user&.admin?
          articles = articles.where(status: 'published')
          Rails.logger.info "ArticlesController#index: Фильтруем только опубликованные статьи"
        else
          Rails.logger.info "ArticlesController#index: Показываем все статьи для админа"
        end
        
        articles = articles.order(created_at: :desc)

        # Фильтрация по категории
        if params[:category].present?
          articles = articles.where(category: params[:category])
        end

        # Фильтрация по избранным статьям
        if params[:featured] == 'true'
          articles = articles.where(featured: true)
        end

        # Поиск по заголовку и содержимому
        if params[:search].present?
          search_term = "%#{params[:search]}%"
          articles = articles.where(
            "title ILIKE ? OR content ILIKE ? OR excerpt ILIKE ?", 
            search_term, search_term, search_term
          )
        end

        # Пагинация
        page = [params[:page].to_i, 1].max  # Минимум 1
        per_page = [params[:per_page].to_i, 10].max  # Минимум 10
        per_page = [per_page, 50].min # Максимум 50 статей за раз

        offset = (page - 1) * per_page
        total = articles.count
        articles = articles.limit(per_page).offset(offset)

        # Определяем язык из параметров или заголовков
        locale = params[:locale] || request.headers['Accept-Language']&.split(',')&.first || 'ru'

        render json: {
          data: articles.map do |article|
            {
              id: article.id,
              title: article.localized_title(locale),
              title_uk: article.title_uk,
              excerpt: article.localized_excerpt(locale),
              excerpt_uk: article.excerpt_uk,
              category: article.category,
              status: article.status,
              featured: article.featured,
              reading_time: article.reading_time,
              views_count: article.views_count,
              author: article.author&.first_name || 'Експерт',
              published_at: article.published_at,
              created_at: article.created_at,
              slug: article.slug,
              featured_image_url: article.featured_image_url,
              tags: article.tags || []
            }
          end,
          meta: {
            current_page: page,
            per_page: per_page,
            total_pages: (total.to_f / per_page).ceil,
            total_count: total
          }
        }
      end
      
      # GET /api/v1/articles/:id
      def show
        # Увеличиваем счетчик просмотров
        @article.increment!(:views_count)

        # Определяем язык из параметров или заголовков
        locale = params[:locale] || request.headers['Accept-Language']&.split(',')&.first || 'ru'

        render json: {
          id: @article.id,
          title: @article.localized_title(locale),
          title_uk: @article.title_uk,
          content: @article.localized_content(locale),
          content_uk: @article.content_uk,
          excerpt: @article.localized_excerpt(locale),
          excerpt_uk: @article.excerpt_uk,
          category: @article.category,
          featured: @article.featured,
          reading_time: @article.reading_time,
          views_count: @article.views_count,
          author: @article.author&.first_name || 'Експерт',
          published_at: @article.published_at,
          slug: @article.slug,
          featured_image_url: @article.featured_image_url,
          gallery_images: @article.gallery_images || [],
          tags: @article.tags || [],
          meta_title: @article.localized_meta_title(locale),
          meta_title_uk: @article.meta_title_uk,
          meta_description: @article.localized_meta_description(locale),
          meta_description_uk: @article.meta_description_uk,
          allow_comments: @article.allow_comments,
          # Добавляем все поля для админки
          title_ru: @article.title,
          content_ru: @article.content,
          excerpt_ru: @article.excerpt,
          meta_title_ru: @article.meta_title,
          meta_description_ru: @article.meta_description,
          title_uk: @article.title_uk,
          content_uk: @article.content_uk,
          excerpt_uk: @article.excerpt_uk,
          meta_title_uk: @article.meta_title_uk,
          meta_description_uk: @article.meta_description_uk
        }
      end
      
      # POST /api/v1/articles
      def create
        @article = @current_user.authored_articles.build(article_params)
        
        if @article.save
          render json: article_full_json(@article), status: :created
        else
          render json: { 
            errors: @article.errors.attribute_names,
            message: 'Не удалось создать статью. Проверьте правильность введенных данных.'
          }, status: :unprocessable_entity
        end
      end
      
      # PUT /api/v1/articles/:id
      def update
        if @article.update(article_params)
          render json: article_full_json(@article)
        else
          render json: { 
            errors: @article.errors.full_messages,
            message: 'Не удалось обновить статью. Проверьте правильность введенных данных.'
          }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/articles/:id
      def destroy
        @article.destroy!
        head :no_content
      rescue StandardError => e
        render json: { 
          error: e.message,
          message: 'Не удалось удалить статью.'
        }, status: :unprocessable_entity
      end
      
      # GET /api/v1/articles/categories
      def categories
        categories_with_counts = Article.where(status: 'published')
                                       .group(:category)
                                       .count

        categories_data = categories_with_counts.map do |category, count|
          {
            name: category,
            count: count,
            display_name: translate_category(category)
          }
        end.sort_by { |cat| cat[:display_name] }

        render json: { data: categories_data }
      end
      
      # GET /api/v1/articles/popular
      def popular
        @articles = Article.published
                          .popular
                          .limit(params[:limit] || 5)
                          .includes(:author)
        
        render json: {
          data: @articles.map { |article| article_summary_json(article) }
        }
      end
      
      # GET /api/v1/articles/related/:id
      def related
        article = Article.find(params[:id])
        
        @related_articles = Article.published
                                  .where.not(id: article.id)
                                  .by_category(article.category)
                                  .recent
                                  .limit(params[:limit] || 3)
                                  .includes(:author)
        
        render json: {
          data: @related_articles.map { |article| article_summary_json(article) }
        }
      end
      
      private
      
      def set_article
        # Сначала пытаемся найти по slug, затем по ID
        @article = Article.find_by(slug: params[:id]) || Article.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Стаття не знайдена' }, status: :not_found
      end
      
      def article_params
        params.require(:article).permit(
          :title, :content, :excerpt, :category, :status, :featured,
          :meta_title, :meta_description, :featured_image_url, :allow_comments,
          :title_uk, :content_uk, :excerpt_uk, :meta_title_uk, :meta_description_uk,
          tags: [], gallery_images: []
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
      
      # Краткая информация о статье для списка
      def article_summary_json(article)
        # Определяем язык из параметров или заголовков
        locale = params[:locale] || request.headers['Accept-Language']&.split(',')&.first || 'ru'
        
        {
          id: article.id,
          title: article.localized_title(locale),
          excerpt: article.localized_excerpt(locale).presence || article.excerpt_or_truncated_content,
          category: article.category,
          category_name: article.category_name,
          status: article.status,
          featured: article.featured,
          slug: article.slug,
          featured_image: article.featured_image,
          reading_time: article.reading_time,
          views_count: article.views_count,
          published_at: article.published_at,
          created_at: article.created_at,
          author_id: article.author.id,
          author: {
            id: article.author.id,
            name: "#{article.author.first_name} #{article.author.last_name}".strip,
            email: article.author.email
          },
          # Добавляем все поля для админки
          title_ru: article.title,
          content_ru: article.content,
          excerpt_ru: article.excerpt,
          meta_title_ru: article.meta_title,
          meta_description_ru: article.meta_description,
          title_uk: article.title_uk,
          content_uk: article.content_uk,
          excerpt_uk: article.excerpt_uk,
          meta_title_uk: article.meta_title_uk,
          meta_description_uk: article.meta_description_uk
        }
      end
      
      # Полная информация о статье
      def article_full_json(article)
        # Определяем язык из параметров или заголовков
        locale = params[:locale] || request.headers['Accept-Language']&.split(',')&.first || 'ru'
        
        article_summary_json(article).merge(
          content: article.localized_content(locale),
          meta_title: article.localized_meta_title(locale),
          meta_description: article.localized_meta_description(locale),
          gallery_images: article.gallery_images,
          tags: article.tags,
          allow_comments: article.allow_comments,
          updated_at: article.updated_at
        )
      end
      
      def translate_category(category)
        translations = {
          'tips' => 'Поради',
          'maintenance' => 'Обслуговування',
          'safety' => 'Безпека',
          'reviews' => 'Огляди',
          'news' => 'Новини',
          'selection' => 'Вибір шин'
        }
        
        translations[category] || category.humanize
      end
    end
  end
end