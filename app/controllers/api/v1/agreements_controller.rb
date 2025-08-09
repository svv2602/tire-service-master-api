# Контроллер для управления договоренностями партнеров с поставщиками (админская часть)
class Api::V1::AgreementsController < ApplicationController
  before_action :authenticate_request
  before_action :set_agreement, only: [:show, :update, :destroy]
  
  # GET /api/v1/agreements
  def index
    authorize PartnerSupplierAgreement, :index?
    
    @agreements = policy_scope(PartnerSupplierAgreement)
                   .includes(partner: :user, supplier: [])
                   .order(:created_at)
    
    # Фильтрация
    @agreements = @agreements.where(active: params[:active]) if params[:active].present?
    @agreements = @agreements.where(partner_id: params[:partner_id]) if params[:partner_id].present?
    @agreements = @agreements.where(supplier_id: params[:supplier_id]) if params[:supplier_id].present?
    @agreements = @agreements.where(order_types: params[:order_types]) if params[:order_types].present?
    
    # Пагинация
    page = params[:page]&.to_i || 1
    per_page = [params[:per_page]&.to_i || 20, 100].min
    
    total_count = @agreements.count
    @agreements = @agreements.offset((page - 1) * per_page).limit(per_page)
    
    render json: {
      data: @agreements.map { |agreement| serialize_agreement(agreement) },
      meta: {
        total_count: total_count,
        page: page,
        per_page: per_page,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end
  
  # GET /api/v1/agreements/:id
  def show
    authorize @agreement, :show?
    
    render json: {
      data: serialize_agreement(@agreement)
    }
  end
  
  # POST /api/v1/agreements
  def create
    authorize PartnerSupplierAgreement, :create?
    
    @agreement = PartnerSupplierAgreement.new(agreement_params)
    
    if @agreement.save
      Rails.logger.info "✅ Создана договоренность: #{@agreement.display_name} (ID: #{@agreement.id})"
      
      render json: {
        data: serialize_agreement(@agreement),
        message: 'Договоренность успешно создана'
      }, status: :created
    else
      Rails.logger.warn "❌ Ошибка создания договоренности: #{@agreement.errors.full_messages.join(', ')}"
      
      render json: {
        errors: @agreement.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  # PATCH/PUT /api/v1/agreements/:id
  def update
    authorize @agreement, :update?
    
    if @agreement.update(agreement_params)
      Rails.logger.info "✅ Обновлена договоренность: #{@agreement.display_name} (ID: #{@agreement.id})"
      
      render json: {
        data: serialize_agreement(@agreement),
        message: 'Договоренность успешно обновлена'
      }
    else
      Rails.logger.warn "❌ Ошибка обновления договоренности: #{@agreement.errors.full_messages.join(', ')}"
      
      render json: {
        errors: @agreement.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  # DELETE /api/v1/agreements/:id
  def destroy
    authorize @agreement, :destroy?
    
    agreement_name = @agreement.display_name
    
    if @agreement.destroy
      Rails.logger.info "✅ Удалена договоренность: #{agreement_name}"
      
      render json: {
        message: 'Договоренность успешно удалена'
      }
    else
      Rails.logger.warn "❌ Ошибка удаления договоренности: #{@agreement.errors.full_messages.join(', ')}"
      
      render json: {
        errors: @agreement.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  # GET /api/v1/agreements/partners
  def partners
    authorize PartnerSupplierAgreement, :index?
    
    @partners = Partner.active.includes(:user).order(:company_name)
    
    render json: {
      data: @partners.map { |partner|
        {
          id: partner.id,
          company_name: partner.company_name,
          contact_person: partner.contact_person,
          phone: partner.phone,
          is_active: partner.is_active?
        }
      }
    }
  end
  
  # GET /api/v1/agreements/suppliers
  def suppliers
    authorize PartnerSupplierAgreement, :index?
    
    @suppliers = Supplier.where(is_active: true).order(:name)
    
    render json: {
      data: @suppliers.map { |supplier|
        {
          id: supplier.id,
          name: supplier.name,
          firm_id: supplier.firm_id,
          is_active: supplier.is_active,
          priority: supplier.priority
        }
      }
    }
  end
  
  private
  
  def set_agreement
    @agreement = PartnerSupplierAgreement.includes(partner: :user, supplier: []).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Договоренность не найдена' }, status: :not_found
  end
  
  def agreement_params
    params.require(:agreement).permit(
      :partner_id, :supplier_id, :start_date, :end_date, 
      :commission_type, :order_types, :active, :description
    )
  end
  
  def serialize_agreement(agreement)
    locale = params[:locale]&.to_sym || :ru
    
    {
      id: agreement.id,
      partner_id: agreement.partner_id,
      supplier_id: agreement.supplier_id,
      start_date: agreement.start_date.to_s,
      end_date: agreement.end_date&.to_s,
      commission_type: agreement.commission_type,
      order_types: agreement.order_types,
      active: agreement.active,
      description: agreement.description,
      created_at: agreement.created_at.to_s,
      updated_at: agreement.updated_at.to_s,
      
      # Информация о партнере
      partner_info: {
        id: agreement.partner.id,
        company_name: agreement.partner.company_name,
        contact_person: agreement.partner.contact_person,
        phone: agreement.partner.user&.phone || '',
        is_active: agreement.partner.is_active?
      },
      
      # Информация о поставщике
      supplier_info: {
        id: agreement.supplier.id,
        name: agreement.supplier.name,
        firm_id: agreement.supplier.firm_id,
        is_active: agreement.supplier.is_active,
        priority: agreement.supplier.priority
      },
      
      # Локализованные тексты
      order_types_text: agreement.order_types_text(locale),
      active_text: agreement.active_text(locale),
      formatted_start_date: agreement.start_date.strftime('%d.%m.%Y'),
      formatted_end_date: agreement.end_date&.strftime('%d.%m.%Y'),
      formatted_created_at: agreement.created_at.strftime('%d.%m.%Y %H:%M'),
      formatted_updated_at: agreement.updated_at.strftime('%d.%m.%Y %H:%M'),
      duration_text: agreement.duration_text,
      status_text: agreement.status_text,
      can_be_edited: agreement.can_be_edited?,
      reward_rules_count: agreement.reward_rules.count,
      active_reward_rules_count: agreement.active_reward_rules.count,
      display_name: agreement.display_name,
      supports_cart_orders: agreement.supports_cart_orders?,
      supports_pickup_orders: agreement.supports_pickup_orders?
    }
  end
end