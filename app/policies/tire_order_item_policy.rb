class TireOrderItemPolicy < ApplicationPolicy
  # Основные права доступа
  def index?
    tire_order_access?
  end

  def show?
    tire_order_access?
  end

  def create?
    user.present? && record.tire_order&.draft? && tire_order_access?
  end

  def update?
    user.present? && record.tire_order&.draft? && tire_order_access?
  end

  def destroy?
    user.present? && record.tire_order&.draft? && tire_order_access?
  end

  # Скоуп для фильтрации записей
  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.joins(:tire_order).where(tire_orders: { user: user })
      end
    end
  end

  private

  def tire_order_access?
    return false unless record.tire_order.present?
    
    user&.admin? || record.tire_order.user == user
  end
end