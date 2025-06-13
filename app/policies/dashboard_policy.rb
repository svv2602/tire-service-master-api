class DashboardPolicy < ApplicationPolicy
  def show?
    # Только администраторы, менеджеры и партнеры могут видеть дашборд
    user.present? && (user.admin? || user.manager? || user.partner?)
  end
  
  # Для партнера разрешаем видеть только его собственную статистику
  def show_partner_stats?(dashboard_record, options = {})
    # В тестах параметр partner передается как options[:partner]
    # В контроллере параметр partner передается как dashboard_record[:partner]
    partner = nil
    
    if dashboard_record.is_a?(Hash) && dashboard_record[:partner]
      partner = dashboard_record[:partner]
    elsif options.is_a?(Hash) && options[:partner]
      partner = options[:partner]
    end
    
    return false unless user.present?
    return true if user.admin? || user.manager?
    
    # Для партнера проверяем, что это его статистика
    if user.partner? && user.partner.present? && partner.present?
      return user.partner.id == partner.id
    end
    
    false
  end
end 