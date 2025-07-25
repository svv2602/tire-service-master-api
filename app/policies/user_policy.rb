class UserPolicy < ApplicationPolicy
  def index?
    user.admin?
  end

  def show?
    user.admin? || user.id == record.id
  end

  def create?
    user.admin?
  end

  def update?
    user.admin? || user.id == record.id
  end

  def destroy?
    user.admin? && user.id != record.id
  end

  def manage?
    user.admin?
  end

  # Методы для блокировки пользователей
  def suspend?
    return false unless user.present?
    return false if user.id == record.id # Нельзя заблокировать себя
    
    # Админы и менеджеры могут блокировать
    return true if user.admin? || user.manager?
    
    # Партнеры могут блокировать только своих операторов
    if user.partner? && record.operator?
      return record.operator.partner_id == user.partner.id
    end
    
    false
  end

  def unsuspend?
    return false unless user.present?
    return false unless record.suspended?
    
    # Админы и менеджеры могут разблокировать
    return true if user.admin? || user.manager?
    
    # Партнеры могут разблокировать только своих операторов
    if user.partner? && record.operator?
      return record.operator.partner_id == user.partner.id
    end
    
    false
  end

  def suspension_info?
    show? # Те же права, что и для просмотра пользователя
  end

  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(id: user.id)
      end
    end
  end
end
