# Политика доступа для вознаграждений партнеров
class PartnerRewardPolicy < ApplicationPolicy
  # Скоуп для фильтрации записей в зависимости от роли пользователя
  class Scope < Scope
    def resolve
      if user.admin?
        # Администраторы видят все вознаграждения
        scope.all
      elsif user.partner?
        # Партнеры видят только свои вознаграждения
        scope.where(partner: user.partner)
      else
        # Остальные пользователи не имеют доступа
        scope.none
      end
    end
  end
  
  def index?
    user.admin? || user.partner?
  end
  
  def show?
    user.admin? || partner_owns_reward?
  end
  
  def create?
    # Вознаграждения создаются только автоматически системой
    false
  end
  
  def update?
    return false unless show?
    
    # Администраторы могут редактировать любые поля
    return true if user.admin?
    
    # Партнеры могут редактировать только notes у своих вознаграждений
    partner_owns_reward?
  end
  
  def destroy?
    # Вознаграждения не удаляются, только отменяются
    false
  end
  
  def mark_as_paid?
    # Только администраторы могут отмечать выплаты
    user.admin? && show?
  end
  
  def cancel?
    # Только администраторы могут отменять вознаграждения
    user.admin? && show? && record.can_be_cancelled?
  end
  
  def statistics?
    user.admin? || user.partner?
  end
  
  def export?
    user.admin? || user.partner?
  end
  
  private
  
  def partner_owns_reward?
    user.partner? && record.partner == user.partner
  end
end