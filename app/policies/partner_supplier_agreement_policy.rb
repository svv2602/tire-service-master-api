# Политика доступа для договоренностей партнер-поставщик
class PartnerSupplierAgreementPolicy < ApplicationPolicy
  # Скоуп для фильтрации записей в зависимости от роли пользователя
  class Scope < Scope
    def resolve
      if user.admin?
        # Администраторы видят все договоренности
        scope.all
      elsif user.partner?
        # Партнеры видят только свои договоренности
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
    user.admin? || (user.partner? && record.partner == user.partner)
  end
  
  def create?
    user.admin? || user.partner?
  end
  
  def update?
    return false unless show?
    
    # Только активные договоренности можно редактировать
    record.can_be_edited?
  end
  
  def destroy?
    return false unless show?
    
    # Администраторы могут удалять любые договоренности
    return true if user.admin?
    
    # Партнеры могут удалять только свои неактивные договоренности
    user.partner? && record.partner == user.partner && !record.active?
  end
  
  def available_suppliers?
    user.admin? || user.partner?
  end
  
  private
  
  def partner_owns_record?
    user.partner? && record.partner == user.partner
  end
end