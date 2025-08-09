# API контроллер для управления исключениями в договоренностях партнеров с поставщиками
class Api::V1::PartnerSupplierAgreementExceptionsController < ApplicationController
  before_action :authenticate_request
  before_action :set_agreement
  before_action :set_exception, only: [:show, :update, :destroy]
  
  # GET /api/v1/agreements/:agreement_id/exceptions
  def index
    authorize @agreement, :show?
    
    @exceptions = @agreement.exceptions.includes(:tire_brand)
    
    # Фильтрация
    @exceptions = @exceptions.where(active: params[:active]) if params[:active].present?
    @exceptions = @exceptions.where(tire_brand_id: params[:tire_brand_id]) if params[:tire_brand_id].present?
    @exceptions = @exceptions.where(tire_diameter: params[:tire_diameter]) if params[:tire_diameter].present?
    @exceptions = @exceptions.where(exception_type: params[:exception_type]) if params[:exception_type].present?
    
    # Сортировка по приоритету (высший приоритет первым)
    @exceptions = @exceptions.by_priority
    
    # Пагинация
    page = params[:page]&.to_i || 1
    per_page = [params[:per_page]&.to_i || 20, 100].min
    
    @pagy, @exceptions = pagy(@exceptions, items: per_page, page: page)
    
    render json: {
      data: @exceptions.map { |exception| serialize_exception(exception) },
      meta: {
        current_page: @pagy.page,
        per_page: @pagy.items,
        total_pages: @pagy.pages,
        total_count: @pagy.count
      }
    }
  end
  
  # GET /api/v1/agreements/:agreement_id/exceptions/:id
  def show
    authorize @agreement, :show?
    
    render json: {
      data: serialize_exception(@exception)
    }
  end
  
  # POST /api/v1/agreements/:agreement_id/exceptions
  def create
    authorize @agreement, :update?
    
    @exception = @agreement.exceptions.build(exception_params.except(:tire_brand_ids, :tire_diameters))
    
    if @exception.save
      # Добавляем множественные бренды и диаметры
      handle_multiple_brands_and_diameters(@exception, exception_params)
      
      render json: {
        data: serialize_exception(@exception.reload),
        message: 'Исключение успешно создано'
      }, status: :created
    else
      render json: {
        errors: @exception.errors.full_messages,
        message: 'Ошибка при создании исключения'
      }, status: :unprocessable_entity
    end
  end
  
  # PATCH/PUT /api/v1/agreements/:agreement_id/exceptions/:id
  def update
    authorize @agreement, :update?
    
    if @exception.update(exception_params.except(:tire_brand_ids, :tire_diameters))
      # Обновляем множественные бренды и диаметры
      handle_multiple_brands_and_diameters(@exception, exception_params)
      
      render json: {
        data: serialize_exception(@exception.reload),
        message: 'Исключение успешно обновлено'
      }
    else
      render json: {
        errors: @exception.errors.full_messages,
        message: 'Ошибка при обновлении исключения'
      }, status: :unprocessable_entity
    end
  end
  
  # DELETE /api/v1/agreements/:agreement_id/exceptions/:id
  def destroy
    authorize @agreement, :update?
    
    if @exception.destroy
      render json: {
        message: 'Исключение успешно удалено'
      }
    else
      render json: {
        errors: @exception.errors.full_messages,
        message: 'Ошибка при удалении исключения'
      }, status: :unprocessable_entity
    end
  end
  
  # GET /api/v1/agreements/:agreement_id/exceptions/tire_brands
  def tire_brands
    authorize @agreement, :show?
    
    # Получаем все бренды шин из системы (предполагается, что есть модель TireBrand)
    brands = if defined?(TireBrand)
      TireBrand.where(is_active: true).order(:name)
    else
      # Если модели нет, создаем заглушку
      []
    end
    
    render json: {
      data: brands.map { |brand| { id: brand.id, name: brand.name } }
    }
  end
  
  # GET /api/v1/agreements/:agreement_id/exceptions/tire_diameters
  def tire_diameters
    authorize @agreement, :show?
    
    # Популярные диаметры шин
    popular_diameters = %w[13 14 15 16 17 18 19 20 21 22]
    
    render json: {
      data: popular_diameters.map { |diameter| { value: diameter, label: "#{diameter}\"" } }
    }
  end
  
  private
  
  def set_agreement
    @agreement = PartnerSupplierAgreement.find(params[:agreement_id])
  rescue ActiveRecord::RecordNotFound
    render json: { message: 'Договоренность не найдена' }, status: :not_found
  end
  
  def set_exception
    @exception = @agreement.exceptions.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { message: 'Исключение не найдено' }, status: :not_found
  end
  
  def exception_params
    params.require(:exception).permit(
      :tire_brand_id,
      :tire_diameter,
      :exception_type,
      :exception_amount,
      :exception_percentage,
      :application_scope,
      :priority,
      :active,
      :description,
      # Новые параметры для множественного выбора
      tire_brand_ids: [],
      tire_diameters: []
    )
  end
  
  def serialize_exception(exception)
    locale = params[:locale]&.to_sym || :ru
    
    {
      id: exception.id,
      partner_supplier_agreement_id: exception.partner_supplier_agreement_id,
      tire_brand_id: exception.tire_brand_id,
      tire_diameter: exception.tire_diameter,
      exception_type: exception.exception_type,
      exception_amount: exception.exception_amount,
      exception_percentage: exception.exception_percentage,
      application_scope: exception.application_scope,
      priority: exception.priority,
      active: exception.active,
      description: exception.description,
      created_at: exception.created_at.iso8601,
      updated_at: exception.updated_at.iso8601,
      
      # Дополнительная информация (совместимость)
      tire_brand_name: exception.tire_brand&.name,
      exception_type_text: exception.exception_type_text(locale),
      application_scope_text: exception.application_scope_text(locale),
      tire_brand_text: exception.tire_brand_text(locale),
      tire_diameter_text: exception.tire_diameter_text(locale),
      value_text: exception.value_text,
      full_description: exception.full_description(locale),
      
      # Новые поля для множественного выбора
      tire_brand_ids: exception.all_brand_ids,
      tire_diameters: exception.all_diameters,
      brands_description: exception.brands_description(locale),
      diameters_description: exception.diameters_description(locale),
      full_description_with_multiple: exception.full_description_with_multiple(locale),
      
      # Детальная информация о брендах и диаметрах
      exception_brands: exception.exception_brands.includes(:tire_brand).map { |eb| 
        { id: eb.id, tire_brand_id: eb.tire_brand_id, tire_brand_name: eb.brand_name }
      },
      exception_diameters: exception.exception_diameters.map { |ed|
        { id: ed.id, tire_diameter: ed.tire_diameter, formatted_diameter: ed.formatted_diameter }
      },
      
      # Форматированные даты
      formatted_created_at: exception.created_at.strftime('%d.%m.%Y %H:%M'),
      formatted_updated_at: exception.updated_at.strftime('%d.%m.%Y %H:%M')
    }
  end
  
  # Обработка множественных брендов и диаметров
  def handle_multiple_brands_and_diameters(exception, params)
    # Обработка брендов
    if params[:tire_brand_ids].present?
      brand_ids = Array(params[:tire_brand_ids]).reject(&:blank?).map(&:to_i)
      exception.set_brands!(brand_ids)
    end
    
    # Обработка диаметров
    if params[:tire_diameters].present?
      diameters = Array(params[:tire_diameters]).reject(&:blank?)
      exception.set_diameters!(diameters)
    end
  end
end