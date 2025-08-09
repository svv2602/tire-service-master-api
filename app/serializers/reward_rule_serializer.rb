# Сериализатор для правил вознаграждений
class RewardRuleSerializer
  include JSONAPI::Serializer
  
  attributes :id, :rule_type, :amount, :conditions, :priority, :active, 
             :description, :created_at, :updated_at
  
  # Виртуальные атрибуты
  attribute :rule_type_display do |rule|
    rule.rule_type_display
  end
  
  attribute :amount_display do |rule|
    rule.amount_display
  end
  
  attribute :conditions_hash do |rule|
    rule.conditions_hash
  end
  
  attribute :conditions_description do |rule|
    rule.conditions_description
  end
  
  # Связи не используем в этой версии сериализатора для упрощения
  
  # Информация о договоренности
  attribute :agreement_info, if: Proc.new { |record, params|
    params && params[:include_agreement_info]
  } do |rule|
    agreement = rule.partner_supplier_agreement
    {
      id: agreement.id,
      partner_name: agreement.partner.company_name,
      supplier_name: agreement.supplier.name,
      display_name: agreement.display_name,
      active: agreement.active,
      current: agreement.current?
    }
  end
  
  # Статистика применения правила
  attribute :usage_statistics, if: Proc.new { |record, params|
    params && params[:include_statistics]
  } do |rule|
    rewards = rule.partner_rewards
    {
      total_rewards: rewards.count,
      total_amount: rewards.sum(:calculated_amount),
      pending_count: rewards.pending.count,
      paid_count: rewards.paid.count,
      cancelled_count: rewards.cancelled.count,
      last_used: rewards.order(:calculated_at).last&.calculated_at&.strftime('%d.%m.%Y')
    }
  end
  
  # Примеры расчетов для демонстрации
  attribute :calculation_examples, if: Proc.new { |record, params|
    params && params[:include_examples]
  } do |rule|
    examples = []
    
    case rule.rule_type
    when 'fixed_per_order'
      examples << {
        scenario: 'Любой заказ',
        description: 'Фиксированная сумма независимо от содержимого',
        order_amount: 5000,
        items_count: 4,
        reward_amount: rule.amount
      }
    when 'percentage'
      [1000, 5000, 10000].each do |amount|
        examples << {
          scenario: "Заказ на #{amount} грн",
          description: "#{rule.amount}% от суммы заказа",
          order_amount: amount,
          items_count: 4,
          reward_amount: (amount * rule.amount / 100).round(2)
        }
      end
    when 'fixed_per_item'
      [1, 2, 4].each do |count|
        examples << {
          scenario: "#{count} #{count == 1 ? 'товар' : 'товара'}",
          description: "#{rule.amount} грн за единицу товара",
          order_amount: count * 1000,
          items_count: count,
          reward_amount: count * rule.amount
        }
      end
    end
    
    examples
  end
end