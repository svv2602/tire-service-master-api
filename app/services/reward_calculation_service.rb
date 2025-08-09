# Сервис для автоматического расчета вознаграждений партнеров
class RewardCalculationService
  attr_reader :order, :errors
  
  def initialize(order)
    @order = order
    @errors = []
  end
  
  # Главный метод для расчета и создания вознаграждения
  def calculate_and_create_reward
    return false unless valid_order?
    
    partner = find_partner
    return false unless partner
    
    supplier = find_supplier
    return false unless supplier
    
    agreement = find_active_agreement(partner, supplier)
    return false unless agreement
    
    rule = find_applicable_rule(agreement)
    return false unless rule
    
    reward_amount = rule.calculate_reward(@order)
    return false if reward_amount <= 0
    
    create_partner_reward(partner, supplier, rule, reward_amount)
  end
  
  # Метод для пересчета вознаграждения при изменении заказа
  def recalculate_existing_reward
    existing_reward = find_existing_reward
    return false unless existing_reward
    
    # Пересчитываем только если вознаграждение еще не выплачено
    return false unless existing_reward.pending?
    
    rule = existing_reward.reward_rule
    new_amount = rule.calculate_reward(@order)
    
    if new_amount <= 0
      existing_reward.cancel!('Заказ больше не соответствует условиям')
      return true
    end
    
    existing_reward.update!(
      calculated_amount: new_amount,
      calculated_at: Time.current,
      notes: [existing_reward.notes, 'Пересчитано при изменении заказа'].compact.join('; ')
    )
  end
  
  # Проверяет, есть ли уже вознаграждение для данного заказа
  def reward_exists?
    find_existing_reward.present?
  end
  
  # Получает информацию о возможном вознаграждении без создания записи
  def preview_reward
    return nil unless valid_order?
    
    partner = find_partner
    return nil unless partner
    
    supplier = find_supplier
    return nil unless supplier
    
    agreement = find_active_agreement(partner, supplier)
    return nil unless agreement
    
    rule = find_applicable_rule(agreement)
    return nil unless rule
    
    reward_amount = rule.calculate_reward(@order)
    return nil if reward_amount <= 0
    
    {
      partner: partner,
      supplier: supplier,
      agreement: agreement,
      rule: rule,
      amount: reward_amount,
      rule_description: rule.conditions_description
    }
  end
  
  private
  
  def valid_order?
    if @order.nil?
      @errors << 'Заказ не найден'
      return false
    end
    
    unless @order.is_a?(TireOrder) || @order.is_a?(Order)
      @errors << 'Неподдерживаемый тип заказа'
      return false
    end
    
    # Проверяем статус заказа
    if @order.is_a?(TireOrder) && !%w[submitted confirmed completed].include?(@order.status)
      @errors << 'Заказ должен быть отправлен, подтвержден или выполнен'
      return false
    end
    
    if @order.is_a?(Order) && !%w[received processing ready delivered].include?(@order.status)
      @errors << 'Заказ должен быть получен, в обработке, готов или выдан'
      return false
    end
    
    true
  end
  
  def find_partner
    partner = if @order.is_a?(TireOrder)
                # Для заказов через корзину - находим партнера через пользователя
                user = @order.user
                user&.partner? ? user.partner : nil
              elsif @order.is_a?(Order)
                # Для заказов интернет-магазинов - находим через сервисную точку
                @order.service_point&.partner
              end
    
    unless partner
      @errors << 'Не удалось определить партнера для заказа'
      return nil
    end
    
    unless partner.is_active?
      @errors << 'Партнер неактивен'
      return nil
    end
    
    partner
  end
  
  def find_supplier
    supplier = if @order.is_a?(TireOrder)
                 @order.supplier
               elsif @order.is_a?(Order)
                 @order.supplier
               end
    
    unless supplier
      @errors << 'Не удалось определить поставщика для заказа'
      return nil
    end
    
    unless supplier.active?
      @errors << 'Поставщик неактивен'
      return nil
    end
    
    supplier
  end
  
  def find_active_agreement(partner, supplier)
    agreement = PartnerSupplierAgreement
                  .where(partner: partner, supplier: supplier)
                  .active
                  .current
                  .first
    
    unless agreement
      @errors << 'Нет активных договоренностей между партнером и поставщиком'
      return nil
    end
    
    agreement
  end
  
  def find_applicable_rule(agreement)
    rule = agreement.applicable_rule_for_order(@order)
    
    unless rule
      @errors << 'Нет применимых правил вознаграждения для данного заказа'
      return nil
    end
    
    rule
  end
  
  def create_partner_reward(partner, supplier, rule, amount)
    reward_params = {
      partner: partner,
      supplier: supplier,
      reward_rule: rule,
      calculated_amount: amount,
      payment_status: 'pending',
      calculated_at: Time.current,
      notes: "Автоматически рассчитано для заказа #{order_identifier}"
    }
    
    # Добавляем ссылку на соответствующий тип заказа
    if @order.is_a?(TireOrder)
      reward_params[:tire_order] = @order
    elsif @order.is_a?(Order)
      reward_params[:order] = @order
    end
    
    begin
      PartnerReward.create!(reward_params)
    rescue ActiveRecord::RecordInvalid => e
      @errors << "Ошибка создания вознаграждения: #{e.message}"
      nil
    end
  end
  
  def find_existing_reward
    if @order.is_a?(TireOrder)
      PartnerReward.find_by(tire_order: @order)
    elsif @order.is_a?(Order)
      PartnerReward.find_by(order: @order)
    end
  end
  
  def order_identifier
    if @order.is_a?(TireOrder)
      "TireOrder ##{@order.id}"
    elsif @order.is_a?(Order)
      "Order ##{@order.ttn}"
    else
      "Unknown ##{@order.id}"
    end
  end
end