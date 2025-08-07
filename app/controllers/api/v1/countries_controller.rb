# frozen_string_literal: true

class Api::V1::CountriesController < Api::V1::ApiController
  before_action :authenticate_request!
  before_action :set_country, only: [:show, :update, :destroy]
  before_action :authorize_admin_or_manager!

  # GET /api/v1/countries
  def index
    @countries = Country.includes(:tire_brands)
                       .order(:name)

    # Фильтрация по поиску
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      @countries = @countries.where(
        'LOWER(name) LIKE ? OR LOWER(iso_code) LIKE ?', 
        search_term, search_term
      )
    end

    # Фильтрация по статусу
    @countries = @countries.where(is_active: true) if params[:active_only] == 'true'

    # Применяем пагинацию через метод paginate из ApiController
    result = paginate(@countries)
    
    # Форматируем данные
    result[:data] = result[:data].map { |country| format_country(country) }

    render json: result
  end

  # GET /api/v1/countries/:id
  def show
    render json: { data: format_country_detailed(@country) }
  end

  # POST /api/v1/countries
  def create
    @country = Country.new(country_params)

    if @country.save
      render json: { 
        data: format_country_detailed(@country),
        message: 'Страна успешно создана'
      }, status: :created
    else
      render json: { 
        errors: @country.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/countries/:id
  def update
    if @country.update(country_params)
      render json: { 
        data: format_country_detailed(@country),
        message: 'Страна успешно обновлена'
      }
    else
      render json: { 
        errors: @country.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/countries/:id
  def destroy
    if @country.tire_brands.exists?
      render json: { 
        error: 'Невозможно удалить страну, у которой есть связанные бренды шин' 
      }, status: :unprocessable_entity
      return
    end

    @country.destroy
    render json: { 
      message: 'Страна успешно удалена' 
    }
  end

  # PATCH /api/v1/countries/:id/toggle_status
  def toggle_status
    @country = Country.find(params[:id])
    @country.update!(is_active: !@country.is_active)
    
    status_text = @country.is_active? ? 'активирована' : 'деактивирована'
    render json: { 
      data: format_country(@country),
      message: "Страна #{status_text}"
    }
  end

  private

  def set_country
    @country = Country.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Страна не найдена' }, status: :not_found
  end

  def country_params
    params.require(:country).permit(
      :name, :iso_code, :is_active, :rating_score, :description,
      aliases: []
    )
  end

  def authorize_admin_or_manager!
    unless current_user&.admin? || current_user&.manager?
      render json: { error: 'Доступ запрещен' }, status: :forbidden
    end
  end

  def format_country(country)
    {
      id: country.id,
      name: country.name,
      iso_code: country.iso_code,
      is_active: country.is_active,
      rating_score: country.rating_score,
      tire_brands_count: country.tire_brands.count,
      created_at: country.created_at.strftime('%Y-%m-%d'),
      updated_at: country.updated_at.strftime('%Y-%m-%d %H:%M')
    }
  end

  def format_country_detailed(country)
    format_country(country).merge(
      description: country.description,
      aliases: country.aliases || [],
      normalized_name: country.normalized_name,
      tire_brands: country.tire_brands.active.limit(10).map do |brand|
        {
          id: brand.id,
          name: brand.name,
          models_count: brand.tire_models.count
        }
      end
    )
  end
end