module Api
  module V1
    class ArticlesController < ApiController
      before_action :authenticate_request, except: [:index, :show, :categories]
      before_action :authorize_admin, except: [:index, :show, :categories]
      before_action :set_article, only: [:show, :update, :destroy]
      
      # GET /api/v1/articles
      def index
        # Если запрашиваются черновики, требуем авторизацию
        if params[:include_drafts].present?
          authenticate_request unless @current_user
          unless @current_user&.admin?
            render json: { 
              error: 'У вас нет прав для просмотра черновиков',
              message: 'Для просмотра черновиков требуются права администратора.'
            }, status: :forbidden
            return
          end
        end
        
        @articles = Article.includes(:author)
        
        # Фильтрация по статусу (только админы могут видеть черновики)
        unless params[:include_drafts].present? && @current_user&.admin?
          @articles = @articles.published
        end
        
        # Фильтры
        @articles = @articles.by_category(params[:category]) if params[:category].present?
        @articles = @articles.featured if params[:featured].present?
        @articles = @articles.search(params[:query]) if params[:query].present?
        
        # Сортировка
        case params[:sort]
        when 'popular'
          @articles = @articles.popular
        when 'oldest'
          @articles = @articles.order(published_at: :asc)
        else
          @articles = @articles.recent
        end
        
        # Пагинация
        page = (params[:page] || 1).to_i
        per_page = [(params[:per_page] || 12).to_i, 50].min # максимум 50 на страницу
        
        total_count = @articles.count
        @articles = @articles.offset((page - 1) * per_page).limit(per_page)
        
        total_pages = (total_count.to_f / per_page).ceil
        
        render json: {
          data: @articles.map { |article| article_summary_json(article) },
          meta: {
            current_page: page,
            total_pages: total_pages,
            total_count: total_count,
            per_page: per_page
          }
        }
      end
      
      # GET /api/v1/articles/:id
      def show
        # Проверяем что статья найдена
        unless @article
          render json: { 
            error: 'Статья не найдена',
            message: 'Запрашиваемая статья не существует.'
          }, status: :not_found
          return
        end
        
        # Если это черновик, требуем аутентификацию
        if @article.draft?
          # Если пользователь не авторизован, пытаемся авторизовать
          unless @current_user
            @current_user = AuthorizeApiRequest.new(request.headers).call
          end
          
          # Если все еще не авторизован или не админ, возвращаем 404
          unless @current_user&.admin?
            render json: { 
              error: 'Статья не найдена',
              message: 'Запрашиваемая статья не существует или недоступна.'
            }, status: :not_found
            return
          end
        end
        
        # Увеличиваем счетчик просмотров (не для админов при предпросмотре)
        unless @current_user&.admin? && params[:preview].present?
          @article.increment_views!
        end
        
        render json: article_full_json(@article)
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
        render json: Article.categories_list
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
        @article = Article.find_by(slug: params[:id]) || Article.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        @article = nil
      end
      
      def article_params
        params.require(:article).permit(
          :title, :content, :excerpt, :category, :status, :featured,
          :meta_title, :meta_description, :featured_image_url, :allow_comments,
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
        {
          id: article.id,
          title: article.title,
          excerpt: article.excerpt_or_truncated_content,
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
          }
        }
      end
      
      # Полная информация о статье
      def article_full_json(article)
        article_summary_json(article).merge(
          content: article.content,
          meta_title: article.meta_title,
          meta_description: article.meta_description,
          gallery_images: article.gallery_images,
          tags: article.tags,
          allow_comments: article.allow_comments,
          updated_at: article.updated_at
        )
      end
    end
  end
end