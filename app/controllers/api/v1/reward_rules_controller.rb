# API контроллер для управления правилами вознаграждений
class Api::V1::RewardRulesController < ApplicationController
  before_action :authenticate_request
  before_action :ensure_partner_or_admin
  before_action :set_reward_rule, only: [:show, :update, :destroy]
  before_action :set_agreement, only: [:index, :create]
  
  # GET /api/v1/partner_supplier_agreements/:agreement_id/reward_rules
  def index
    authorize @agreement, :show?
    
    @rules = @agreement.reward_rules
                       .order(:priority, :created_at)
    
    # Фильтры
    @rules = @rules.where(active: params[:active]) if params[:active].present?
    @rules = @rules.where(rule_type: params[:rule_type]) if params[:rule_type].present?
    
    render json: RewardRuleSerializer.new(@rules).serializable_hash
  end
  
  # GET /api/v1/reward_rules/:id
  def show
    authorize @rule
    render json: RewardRuleSerializer.new(@rule, { 
      include: [:partner_supplier_agreement] 
    }).serializable_hash
  end
  
  # POST /api/v1/partner_supplier_agreements/:agreement_id/reward_rules
  def create
    authorize @agreement, :update?
    
    @rule = @agreement.reward_rules.build(rule_params)
    
    if @rule.save
      render json: RewardRuleSerializer.new(@rule).serializable_hash, 
             status: :created
    else
      render json: { errors: @rule.errors }, status: :unprocessable_entity
    end
  end
  
  # PATCH/PUT /api/v1/reward_rules/:id
  def update
    authorize @rule
    
    if @rule.update(rule_params)
      render json: RewardRuleSerializer.new(@rule).serializable_hash
    else
      render json: { errors: @rule.errors }, status: :unprocessable_entity
    end
  end
  
  # DELETE /api/v1/reward_rules/:id
  def destroy
    authorize @rule
    
    if @rule.destroy
      head :no_content
    else
      render json: { errors: @rule.errors }, status: :unprocessable_entity
    end
  end
  
  # POST /api/v1/reward_rules/:id/preview
  # Предварительный расчет вознаграждения по правилу
  def preview
    authorize @rule, :show?
    
    # Параметры для тестирования правила
    test_order_data = {
      total_amount: params[:total_amount]&.to_f || 0,
      items_count: params[:items_count]&.to_i || 1,
      brands: params[:brands] || [],
      diameters: params[:diameters] || []
    }
    
    # Создаем фейковый объект заказа для тестирования
    mock_order = OpenStruct.new(test_order_data)
    
    applicable = @rule.applies_to_order?(mock_order)
    amount = applicable ? @rule.calculate_reward(mock_order) : 0
    
    render json: {
      rule_id: @rule.id,
      rule_type: @rule.rule_type,
      rule_description: @rule.rule_type_display,
      conditions: @rule.conditions_description,
      applicable: applicable,
      calculated_amount: amount,
      test_data: test_order_data
    }
  end
  
  # GET /api/v1/reward_rules/rule_types
  # Получить доступные типы правил
  def rule_types
    render json: {
      rule_types: RewardRule::RULE_TYPES.map do |key, display|
        {
          key: key,
          display: display,
          description: rule_type_description(key)
        }
      end
    }
  end
  
  private
  
  def set_reward_rule
    @rule = RewardRule.find(params[:id])
  end
  
  def set_agreement
    @agreement = PartnerSupplierAgreement.find(params[:agreement_id])
  end
  
  def rule_params
    params.require(:reward_rule).permit(
      :rule_type, :amount, :priority, :active, :description,
      :conditions # JSON поле с условиями
    )
  end
  
  def ensure_partner_or_admin
    unless current_user.partner? || current_user.admin?
      render json: { error: 'Доступ разрешен только партнерам и администраторам' }, 
             status: :forbidden
    end
  end
  
  def rule_type_description(type)
    case type
    when 'fixed_per_order'
      'Фиксированная сумма за каждый заказ независимо от его содержимого'
    when 'percentage'
      'Процент от общей суммы заказа'
    when 'fixed_per_item'
      'Фиксированная сумма за каждую единицу товара в заказе'
    else
      'Неизвестный тип правила'
    end
  end
end