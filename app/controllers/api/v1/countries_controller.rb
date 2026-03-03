# frozen_string_literal: true

class Api::V1::CountriesController < Api::V1::ApiController
  skip_before_action :authenticate_request, only: [:index, :show]
  before_action :authenticate_request!, except: [:index, :show]
  before_action :set_country, only: [:show, :update, :destroy]
  before_action :authorize_admin_or_manager!, except: [:index, :show]
  skip_after_action :verify_authorized

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
    puts "🔍 COUNTRIES UPDATE DEBUG:"
    puts "  Country ID: #{@country.id}"
    puts "  Current country data: #{@country.attributes.inspect}"
    puts "  Received params: #{params.inspect}"
    puts "  Country update params: #{country_params.inspect}"
    
    old_values = @country.as_json
    
    if @country.update(country_params)
      puts "  ✅ Update successful"
      render json: { 
        data: format_country_detailed(@country),
        message: 'Страна успешно обновлена'
      }
    else
      puts "  ❌ Update failed with errors: #{@country.errors.full_messages}"
      puts "  ❌ Detailed errors: #{@country.errors.details}"
      render json: { 
        errors: @country.errors.full_messages 
      }, status: :unprocessable_entity
    end
  rescue => e
    puts "  ❌ General error: #{e.message}"
    puts "  ❌ Backtrace: #{e.backtrace.first(5)}"
    render json: { 
      error: 'Произошла ошибка при обновлении страны',
      details: e.message 
    }, status: :internal_server_error
  end

  # DELETE /api/v1/countries/:id
  def destroy
    puts "🔍 COUNTRIES DELETE DEBUG:"
    puts "  Country ID: #{@country.id}, Name: #{@country.name}"
    puts "  Tire brands count: #{@country.tire_brands.count}"
    puts "  Supplier tire products count: #{@country.supplier_tire_products.count}"
    
    # Проверяем все связанные записи
    if @country.tire_brands.exists?
      puts "  ❌ Блокировка: есть связанные бренды шин"
      render json: { 
        error: 'Невозможно удалить страну, у которой есть связанные бренды шин' 
      }, status: :unprocessable_entity
      return
    end

    if @country.supplier_tire_products.exists?
      puts "  ❌ Блокировка: есть связанные товары поставщиков"
      render json: { 
        error: 'Невозможно удалить страну, у которой есть связанные товары поставщиков' 
      }, status: :unprocessable_entity
      return
    end

    begin
      @country.destroy!
      puts "  ✅ Страна успешно удалена"
      render json: { 
        message: 'Страна успешно удалена' 
      }
    rescue ActiveRecord::DeleteRestrictionError => e
      puts "  ❌ Ошибка удаления: #{e.message}"
      render json: { 
        error: 'Невозможно удалить страну из-за связанных данных' 
      }, status: :unprocessable_entity
    rescue => e
      puts "  ❌ Общая ошибка: #{e.message}"
      render json: { 
        error: 'Произошла ошибка при удалении страны',
        details: e.message 
      }, status: :internal_server_error
    end
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
      :name, :iso_code, :is_active, :rating_score,
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