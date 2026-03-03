# frozen_string_literal: true

class Api::V1::TireBrandsController < Api::V1::ApiController
  skip_before_action :authenticate_request, only: [:index, :show, :top_brands]
  before_action :authenticate_request!, except: [:index, :show, :top_brands]
  before_action :set_tire_brand, only: [:show, :update, :destroy]
  before_action :authorize_admin_or_manager!, except: [:index, :show, :top_brands]
  skip_after_action :verify_authorized

  # GET /api/v1/tire_brands
  def index
    @tire_brands = TireBrand.includes(:country, :tire_models)
                           .order(:name)

    # Фильтрация по поиску
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      @tire_brands = @tire_brands.joins(:country)
                                .where(
                                  'LOWER(tire_brands.name) LIKE ? OR LOWER(countries.name) LIKE ?', 
                                  search_term, search_term
                                )
    end

    # Фильтрация по стране
    @tire_brands = @tire_brands.where(country_id: params[:country_id]) if params[:country_id].present?

    # Фильтрация по статусу
    @tire_brands = @tire_brands.where(is_active: true) if params[:active_only] == 'true'

    # Фильтрация по премиум статусу
    @tire_brands = @tire_brands.where(is_premium: true) if params[:premium_only] == 'true'

    # Применяем пагинацию через метод paginate из ApiController
    result = paginate(@tire_brands)
    
    # Форматируем данные
    result[:data] = result[:data].map { |brand| format_tire_brand(brand) }

    render json: result
  end

  # GET /api/v1/tire_brands/:id
  def show
    render json: { data: format_tire_brand_detailed(@tire_brand) }
  end

  # POST /api/v1/tire_brands
  def create
    @tire_brand = TireBrand.new(tire_brand_params)

    if @tire_brand.save
      render json: { 
        data: format_tire_brand_detailed(@tire_brand),
        message: 'Бренд шин успешно создан'
      }, status: :created
    else
      render json: { 
        errors: @tire_brand.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/tire_brands/:id
  def update
    if @tire_brand.update(tire_brand_params)
      render json: { 
        data: format_tire_brand_detailed(@tire_brand),
        message: 'Бренд шин успешно обновлен'
      }
    else
      render json: { 
        errors: @tire_brand.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/tire_brands/:id
  def destroy
    if @tire_brand.tire_models.exists?
      render json: { 
        error: 'Невозможно удалить бренд, у которого есть модели шин' 
      }, status: :unprocessable_entity
      return
    end

    @tire_brand.destroy
    render json: { 
      message: 'Бренд шин успешно удален' 
    }
  end

  # PATCH /api/v1/tire_brands/:id/toggle_status
  def toggle_status
    @tire_brand = TireBrand.find(params[:id])
    @tire_brand.update!(is_active: !@tire_brand.is_active)
    
    status_text = @tire_brand.is_active? ? 'активирован' : 'деактивирован'
    render json: { 
      data: format_tire_brand(@tire_brand),
      message: "Бренд #{status_text}"
    }
  end

  # GET /api/v1/tire_brands/top_brands
  def top_brands
    limit = params[:limit]&.to_i || 10
    brands = TireBrand.top_brands(limit: limit)
    
    render json: {
      data: brands.map { |brand| format_tire_brand(brand) }
    }
  end

  private

  def set_tire_brand
    @tire_brand = TireBrand.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Бренд шин не найден' }, status: :not_found
  end

  def tire_brand_params
    params.require(:tire_brand).permit(
      :name, :country_id, :is_active, :is_premium, :rating_score,
      aliases: []
    )
  end

  def authorize_admin_or_manager!
    unless current_user&.admin? || current_user&.manager?
      render json: { error: 'Доступ запрещен' }, status: :forbidden
    end
  end

  def format_tire_brand(brand)
    {
      id: brand.id,
      name: brand.name,
      country_id: brand.country_id,
      country_name: brand.country&.name,
      is_active: brand.is_active,
      is_premium: brand.is_premium,
      rating_score: brand.rating_score,
      # logo_url: brand.logo_url, # Поле отсутствует в модели
      models_count: brand.tire_models.count,
      created_at: brand.created_at.strftime('%Y-%m-%d'),
      updated_at: brand.updated_at.strftime('%Y-%m-%d %H:%M')
    }
  end

  def format_tire_brand_detailed(brand)
    format_tire_brand(brand).merge(
      aliases: brand.aliases || [],
      normalized_name: brand.normalized_name,
      tire_models: brand.tire_models.active.limit(10).map do |model|
        {
          id: model.id,
          name: model.name,
          season_type: model.season_type,
          rating_score: model.rating_score
        }
      end,
      country: brand.country ? {
        id: brand.country.id,
        name: brand.country.name,
        iso_code: brand.country.iso_code
      } : nil
    )
  end
end