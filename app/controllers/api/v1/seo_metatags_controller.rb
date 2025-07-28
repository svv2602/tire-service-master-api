class Api::V1::SeoMetatagsController < ApplicationController
  before_action :authenticate_request, except: [:show, :for_page]
  before_action :set_seo_metatag, only: [:show, :update, :destroy]

  # GET /api/v1/seo_metatags
  def index
    authorize SeoMetatag, :index?
    
    @seo_metatags = policy_scope(SeoMetatag)
    @seo_metatags = @seo_metatags.by_language(params[:language]) if params[:language].present?
    @seo_metatags = @seo_metatags.active if params[:active] == 'true'
    
    render json: {
      data: ActiveModel::Serializer::CollectionSerializer.new(@seo_metatags, serializer: SeoMetatagSerializer),
      meta: {
        total: @seo_metatags.count,
        languages: %w[uk ru],
        page_types: SeoMetatag::PAGE_TYPES
      }
    }
  end

  # GET /api/v1/seo_metatags/:id
  def show
    render json: { data: SeoMetatagSerializer.new(@seo_metatag) }
  end

  # GET /api/v1/seo_metatags/for_page/:page_type
  def for_page
    page_type = params[:page_type]
    language = params[:language] || 'uk'
    
    @seo_metatag = SeoMetatag.for_page(page_type, language)
    
    if @seo_metatag
      render json: { data: SeoMetatagSerializer.new(@seo_metatag) }
    else
      render json: { 
        error: 'SEO метатеги не найдены',
        message: "Метатеги для страницы '#{page_type}' на языке '#{language}' не найдены"
      }, status: :not_found
    end
  end

  # POST /api/v1/seo_metatags
  def create
    authorize SeoMetatag, :create?
    
    @seo_metatag = SeoMetatag.new(seo_metatag_params)
    
    if @seo_metatag.save
      render json: { 
        data: SeoMetatagSerializer.new(@seo_metatag),
        message: 'SEO метатеги успешно созданы'
      }, status: :created
    else
      render json: { 
        errors: @seo_metatag.errors.full_messages,
        message: 'Ошибка при создании SEO метатегов'
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/seo_metatags/:id
  def update
    authorize @seo_metatag, :update?
    
    if @seo_metatag.update(seo_metatag_params)
      render json: { 
        data: SeoMetatagSerializer.new(@seo_metatag),
        message: 'SEO метатеги успешно обновлены'
      }
    else
      render json: { 
        errors: @seo_metatag.errors.full_messages,
        message: 'Ошибка при обновлении SEO метатегов'
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/seo_metatags/:id
  def destroy
    authorize @seo_metatag, :destroy?
    
    if @seo_metatag.destroy
      render json: { message: 'SEO метатеги успешно удалены' }
    else
      render json: { 
        errors: @seo_metatag.errors.full_messages,
        message: 'Ошибка при удалении SEO метатегов'
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/seo_metatags/create_defaults
  def create_defaults
    authorize SeoMetatag, :create?
    
    begin
      SeoMetatag.create_defaults!
      render json: { 
        message: 'Стандартные SEO метатеги успешно созданы',
        created_count: SeoMetatag.count
      }
    rescue => e
      render json: { 
        error: e.message,
        message: 'Ошибка при создании стандартных метатегов'
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/seo_metatags/analytics
  def analytics
    authorize SeoMetatag, :index?
    
    metatags = policy_scope(SeoMetatag).active
    
    render json: {
      data: {
        total_pages: metatags.count,
        good_pages: metatags.select { |m| m.seo_status == 'good' }.count,
        warning_pages: metatags.select { |m| m.seo_status == 'warning' }.count,
        error_pages: metatags.select { |m| m.seo_status == 'error' }.count,
        average_title_length: metatags.average('LENGTH(title)').to_i,
        average_description_length: metatags.average('LENGTH(description)').to_i,
        languages_count: metatags.group(:language).count,
        page_types_count: metatags.group(:page_type).count
      }
    }
  end

  private

  def set_seo_metatag
    @seo_metatag = SeoMetatag.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'SEO метатеги не найдены' }, status: :not_found
  end

  def seo_metatag_params
    permitted_params = params.require(:seo_metatag).permit(
      :page_type, :title, :description, :keywords, :image_url, :canonical_url,
      :no_index, :language, :active, keywords_array: []
    )
    
    # Преобразуем массив keywords_array в строку
    if permitted_params[:keywords_array].present?
      permitted_params[:keywords] = permitted_params[:keywords_array].join(', ')
      permitted_params.delete(:keywords_array)
    end
    
    permitted_params
  end
end 