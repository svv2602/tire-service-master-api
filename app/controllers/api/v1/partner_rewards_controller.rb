# API контроллер для управления вознаграждениями партнеров
class Api::V1::PartnerRewardsController < ApplicationController
  before_action :authenticate_request
  before_action :ensure_partner_or_admin
  before_action :set_partner_reward, only: [:show, :update, :mark_as_paid, :cancel]
  
  # GET /api/v1/partner_rewards
  def index
    @rewards = policy_scope(PartnerReward)
                .includes(:partner, :supplier, :reward_rule, :tire_order, :order)
                .order(calculated_at: :desc)
    
    # Фильтрация для партнеров - только их вознаграждения
    if current_user.partner?
      @rewards = @rewards.where(partner: current_user.partner)
    end
    
    # Фильтры
    @rewards = @rewards.where(payment_status: params[:status]) if params[:status].present?
    @rewards = @rewards.where(supplier_id: params[:supplier_id]) if params[:supplier_id].present?
    
    # Фильтр по периоду
    if params[:date_from].present? && params[:date_to].present?
      from_date = Date.parse(params[:date_from])
      to_date = Date.parse(params[:date_to])
      @rewards = @rewards.in_period(from_date.beginning_of_day, to_date.end_of_day)
    end
    
    # Пагинация
    page = params[:page]&.to_i || 1
    per_page = [params[:per_page]&.to_i || 20, 100].min
    @rewards = @rewards.offset((page - 1) * per_page).limit(per_page)
    
    render json: {
      partner_rewards: PartnerRewardSerializer.new(@rewards).serializable_hash,
      pagination: pagination_info(@rewards, page, per_page),
      statistics: current_user.partner? ? 
                    calculate_partner_statistics : 
                    calculate_global_statistics
    }
  end
  
  # GET /api/v1/partner_rewards/:id
  def show
    authorize @reward
    render json: PartnerRewardSerializer.new(@reward, { 
      include: [:partner, :supplier, :reward_rule, :tire_order, :order] 
    }).serializable_hash
  end
  
  # PATCH /api/v1/partner_rewards/:id
  def update
    authorize @reward
    
    # Партнеры могут редактировать только notes
    allowed_params = current_user.partner? ? 
                       update_params.slice(:notes) : 
                       update_params
    
    if @reward.update(allowed_params)
      render json: PartnerRewardSerializer.new(@reward).serializable_hash
    else
      render json: { errors: @reward.errors }, status: :unprocessable_entity
    end
  end
  
  # POST /api/v1/partner_rewards/:id/mark_as_paid
  def mark_as_paid
    authorize @reward, :update?
    
    unless current_user.admin?
      render json: { error: 'Только администраторы могут отмечать выплаты' }, 
             status: :forbidden
      return
    end
    
    if @reward.mark_as_paid!(params[:notes])
      render json: PartnerRewardSerializer.new(@reward).serializable_hash
    else
      render json: { errors: @reward.errors }, status: :unprocessable_entity
    end
  end
  
  # POST /api/v1/partner_rewards/:id/cancel
  def cancel
    authorize @reward, :update?
    
    unless current_user.admin?
      render json: { error: 'Только администраторы могут отменять вознаграждения' }, 
             status: :forbidden
      return
    end
    
    if @reward.cancel!(params[:reason])
      render json: PartnerRewardSerializer.new(@reward).serializable_hash
    else
      render json: { errors: @reward.errors }, status: :unprocessable_entity
    end
  end
  
  # GET /api/v1/partner_rewards/statistics
  def statistics
    if current_user.partner?
      stats = calculate_partner_statistics
      partner_stats = PartnerReward.statistics_for_partner(
        current_user.partner.id,
        params[:date_from]&.to_date,
        params[:date_to]&.to_date
      )
      stats.merge!(partner_stats)
    else
      stats = calculate_global_statistics
    end
    
    render json: { statistics: stats }
  end
  
  # GET /api/v1/partner_rewards/export
  def export
    @rewards = policy_scope(PartnerReward)
                .includes(:partner, :supplier, :reward_rule, :tire_order, :order)
    
    if current_user.partner?
      @rewards = @rewards.where(partner: current_user.partner)
    end
    
    # Применяем те же фильтры что и в index
    @rewards = @rewards.where(payment_status: params[:status]) if params[:status].present?
    @rewards = @rewards.where(supplier_id: params[:supplier_id]) if params[:supplier_id].present?
    
    if params[:date_from].present? && params[:date_to].present?
      from_date = Date.parse(params[:date_from])
      to_date = Date.parse(params[:date_to])
      @rewards = @rewards.in_period(from_date.beginning_of_day, to_date.end_of_day)
    end
    
    @rewards = @rewards.order(:calculated_at)
    
    respond_to do |format|
      format.csv do
        csv_data = generate_csv_export(@rewards)
        send_data csv_data, 
                  filename: "partner_rewards_#{Date.current}.csv",
                  type: 'text/csv'
      end
      format.json do
        render json: PartnerRewardSerializer.new(@rewards).serializable_hash
      end
    end
  end
  
  private
  
  def set_partner_reward
    @reward = PartnerReward.find(params[:id])
  end
  
  def update_params
    params.require(:partner_reward).permit(:payment_status, :paid_at, :notes)
  end
  
  def ensure_partner_or_admin
    unless current_user.partner? || current_user.admin?
      render json: { error: 'Доступ разрешен только партнерам и администраторам' }, 
             status: :forbidden
    end
  end
  
  def calculate_partner_statistics
    partner = current_user.partner
    return {} unless partner
    
    {
      total_pending: PartnerReward.total_amount_for_partner(partner.id, 'pending'),
      total_paid: PartnerReward.total_amount_for_partner(partner.id, 'paid'),
      total_cancelled: PartnerReward.total_amount_for_partner(partner.id, 'cancelled'),
      current_month: PartnerReward.by_partner(partner.id)
                                  .in_period(Date.current.beginning_of_month, Date.current.end_of_month)
                                  .sum(:calculated_amount),
      total_agreements: partner.partner_supplier_agreements.active.count,
      active_suppliers: partner.suppliers.joins(:partner_supplier_agreements)
                              .where(partner_supplier_agreements: { active: true })
                              .count
    }
  end
  
  def calculate_global_statistics
    {
      total_pending: PartnerReward.pending.sum(:calculated_amount),
      total_paid: PartnerReward.paid.sum(:calculated_amount),
      total_cancelled: PartnerReward.cancelled.sum(:calculated_amount),
      total_partners: Partner.joins(:partner_rewards).distinct.count,
      total_suppliers: Supplier.joins(:partner_rewards).distinct.count,
      current_month: PartnerReward.in_period(Date.current.beginning_of_month, Date.current.end_of_month)
                                  .sum(:calculated_amount)
    }
  end
  
  def pagination_info(collection, page, per_page)
    total_count = PartnerReward.count # Приблизительный подсчет
    total_pages = (total_count / per_page.to_f).ceil
    
    {
      current_page: page,
      per_page: per_page,
      total_pages: total_pages,
      total_count: total_count,
      has_next: page < total_pages,
      has_prev: page > 1
    }
  end
  
  def generate_csv_export(rewards)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << [
        'ID', 'Дата расчета', 'Партнер', 'Поставщик', 'Тип заказа', 
        'Номер заказа', 'Правило', 'Сумма', 'Статус', 'Дата выплаты', 'Примечания'
      ]
      
      rewards.each do |reward|
        csv << [
          reward.id,
          reward.formatted_calculated_at,
          reward.partner_company_name,
          reward.supplier_name,
          reward.order_type,
          reward.order_number,
          reward.rule_type_display,
          reward.calculated_amount,
          reward.payment_status_display,
          reward.formatted_paid_at,
          reward.notes
        ]
      end
    end
  end
end