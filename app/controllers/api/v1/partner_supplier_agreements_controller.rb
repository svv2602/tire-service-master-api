# API контроллер для управления договоренностями между партнерами и поставщиками
class Api::V1::PartnerSupplierAgreementsController < ApplicationController
  before_action :authenticate_request
  before_action :ensure_partner_or_admin
  before_action :set_partner_supplier_agreement, only: [:show, :update, :destroy]
  
  # GET /api/v1/partner_supplier_agreements
  def index
    @agreements = policy_scope(PartnerSupplierAgreement)
                    .includes(:partner, :supplier, :reward_rules)
                    .order(:created_at)
    
    # Фильтрация для партнеров - только их договоренности
    if current_user.partner?
      @agreements = @agreements.where(partner: current_user.partner)
    end
    
    # Фильтры
    @agreements = @agreements.where(active: params[:active]) if params[:active].present?
    @agreements = @agreements.where(supplier_id: params[:supplier_id]) if params[:supplier_id].present?
    
    render json: PartnerSupplierAgreementSerializer.new(@agreements).serializable_hash
  end
  
  # GET /api/v1/partner_supplier_agreements/:id
  def show
    authorize @agreement
    render json: PartnerSupplierAgreementSerializer.new(@agreement, { 
      include: [:partner, :supplier, :reward_rules] 
    }).serializable_hash
  end
  
  # POST /api/v1/partner_supplier_agreements
  def create
    @agreement = PartnerSupplierAgreement.new(agreement_params)
    
    # Партнеры могут создавать договоренности только для себя
    if current_user.partner?
      @agreement.partner = current_user.partner
    end
    
    authorize @agreement
    
    if @agreement.save
      render json: PartnerSupplierAgreementSerializer.new(@agreement).serializable_hash, 
             status: :created
    else
      render json: { errors: @agreement.errors }, status: :unprocessable_entity
    end
  end
  
  # PATCH/PUT /api/v1/partner_supplier_agreements/:id
  def update
    authorize @agreement
    
    if @agreement.update(agreement_params)
      render json: PartnerSupplierAgreementSerializer.new(@agreement).serializable_hash
    else
      render json: { errors: @agreement.errors }, status: :unprocessable_entity
    end
  end
  
  # DELETE /api/v1/partner_supplier_agreements/:id
  def destroy
    authorize @agreement
    
    if @agreement.destroy
      head :no_content
    else
      render json: { errors: @agreement.errors }, status: :unprocessable_entity
    end
  end
  
  # GET /api/v1/partner_supplier_agreements/:id/suppliers
  # Получить доступных поставщиков для партнера
  def available_suppliers
    if current_user.partner?
      partner = current_user.partner
      # Все активные поставщики, кроме тех, с которыми уже есть договоренности
      existing_supplier_ids = partner.partner_supplier_agreements.active.pluck(:supplier_id)
      suppliers = Supplier.active.where.not(id: existing_supplier_ids)
    else
      suppliers = Supplier.active
    end
    
    render json: SupplierSerializer.new(suppliers).serializable_hash
  end
  
  private
  
  def set_partner_supplier_agreement
    @agreement = PartnerSupplierAgreement.find(params[:id])
  end
  
  def agreement_params
    params.require(:partner_supplier_agreement).permit(
      :partner_id, :supplier_id, :start_date, :end_date, 
      :commission_type, :active, :description
    )
  end
  
  def ensure_partner_or_admin
    unless current_user.partner? || current_user.admin?
      render json: { error: 'Доступ разрешен только партнерам и администраторам' }, 
             status: :forbidden
    end
  end
end