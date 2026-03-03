# frozen_string_literal: true

class Api::V1::TireModelsController < Api::V1::ApiController
  skip_after_action :verify_authorized
  before_action :authenticate_request!
  before_action :set_tire_model, only: [:show, :update, :destroy]
  before_action :authorize_admin_or_manager!

  # GET /api/v1/tire_models
  def index
    @tire_models = TireModel.includes(:tire_brand, tire_brand: :country)
                           .order('tire_brands.name, tire_models.name')

    # Фильтрация по поиску
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      @tire_models = @tire_models.joins(:tire_brand)
                                .where(
                                  'LOWER(tire_models.name) LIKE ? OR LOWER(tire_brands.name) LIKE ?', 
                                  search_term, search_term
                                )
    end

    # Фильтрация по бренду
    @tire_models = @tire_models.where(tire_brand_id: params[:brand_id]) if params[:brand_id].present?

    # Фильтрация по сезону
    @tire_models = @tire_models.where(season_type: params[:season]) if params[:season].present?

    # Фильтрация по статусу
    @tire_models = @tire_models.where(is_active: true) if params[:active_only] == 'true'

    # Применяем пагинацию через метод paginate из ApiController
    result = paginate(@tire_models)
    
    # Форматируем данные
    result[:data] = result[:data].map { |model| format_tire_model(model) }

    render json: result
  end

  # GET /api/v1/tire_models/:id
  def show
    render json: { data: format_tire_model_detailed(@tire_model) }
  end

  # POST /api/v1/tire_models
  def create
    @tire_model = TireModel.new(tire_model_params)

    if @tire_model.save
      render json: { 
        data: format_tire_model_detailed(@tire_model),
        message: 'Модель шин успешно создана'
      }, status: :created
    else
      render json: { 
        errors: @tire_model.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/tire_models/:id
  def update
    if @tire_model.update(tire_model_params)
      render json: { 
        data: format_tire_model_detailed(@tire_model),
        message: 'Модель шин успешно обновлена'
      }
    else
      render json: { 
        errors: @tire_model.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/tire_models/:id
  def destroy
    if @tire_model.supplier_tire_products.exists?
      render json: { 
        error: 'Невозможно удалить модель, которая используется в продуктах поставщиков' 
      }, status: :unprocessable_entity
      return
    end

    @tire_model.destroy
    render json: { 
      message: 'Модель шин успешно удалена' 
    }
  end

  # PATCH /api/v1/tire_models/:id/toggle_status
  def toggle_status
    @tire_model = TireModel.find(params[:id])
    @tire_model.update!(is_active: !@tire_model.is_active)
    
    status_text = @tire_model.is_active? ? 'активирована' : 'деактивирована'
    render json: { 
      data: format_tire_model(@tire_model),
      message: "Модель #{status_text}"
    }
  end

  # GET /api/v1/tire_models/by_brand/:brand_id
  def by_brand
    brand_id = params[:brand_id]
    models = TireModel.by_brand(brand_id).active.order(:name)
    
    render json: {
      data: models.map { |model| format_tire_model(model) }
    }
  end

  # GET /api/v1/tire_models/seasons
  def seasons
    render json: {
      data: [
        { value: 'summer', label: 'Летние' },
        { value: 'winter', label: 'Зимние' },
        { value: 'all_season', label: 'Всесезонные' }
      ]
    }
  end

  private

  def set_tire_model
    @tire_model = TireModel.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Модель шин не найдена' }, status: :not_found
  end

  def tire_model_params
    params.require(:tire_model).permit(
      :name, :tire_brand_id, :season_type, :is_active, :rating_score,
      aliases: []
    )
  end

  def authorize_admin_or_manager!
    unless current_user&.admin? || current_user&.manager?
      render json: { error: 'Доступ запрещен' }, status: :forbidden
    end
  end

  def format_tire_model(model)
    {
      id: model.id,
      name: model.name,
      tire_brand_id: model.tire_brand_id,
      tire_brand_name: model.tire_brand.name,
      season_type: model.season_type,
      is_active: model.is_active,
      rating_score: model.rating_score,
      available_sizes: model.available_sizes,
      created_at: model.created_at.strftime('%Y-%m-%d'),
      updated_at: model.updated_at.strftime('%Y-%m-%d %H:%M')
    }
  end

  def format_tire_model_detailed(model)
    format_tire_model(model).merge(
      aliases: model.aliases || [],
      normalized_name: model.normalized_name,
      full_name: model.full_name,
      tire_brand: {
        id: model.tire_brand.id,
        name: model.tire_brand.name,
        country_name: model.tire_brand.country&.name,
        is_premium: model.tire_brand.is_premium,
        rating_score: model.tire_brand.rating_score
      },
      supplier_products_count: model.supplier_tire_products.count
    )
  end
end