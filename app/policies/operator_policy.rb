class OperatorPolicy < ApplicationPolicy
  def index?
    user&.admin? || user&.manager? || user&.partner?
  end

  def show?
    return true if user&.admin? || user&.manager?
    return true if user&.partner? && record.partner_id == user.partner.id
    return true if user&.operator? && record.id == user.operator&.id
    false
  end

  def create?
    user&.admin? || user&.manager? || user&.partner?
  end

  def update?
    return true if user&.admin? || user&.manager?
    return true if user&.partner? && record.partner_id == user.partner.id
    return true if user&.operator? && record.id == user.operator&.id
    false
  end

  def destroy?
    return true if user&.admin? || user&.manager?
    return true if user&.partner? && record.partner_id == user.partner.id
    false
  end

  # Новые методы для управления привязками к сервисным точкам
  def assign_to_service_points?
    return true if user&.admin? || user&.manager?
    return true if user&.partner? && record.partner_id == user.partner.id
    false
  end

  def unassign_from_service_points?
    assign_to_service_points?
  end

  def manage_service_point_assignments?
    assign_to_service_points?
  end

  class Scope < Scope
    def resolve
      return scope.all if user&.admin? || user&.manager?
      
      if user&.partner?
        # Партнер видит только своих операторов
        scope.where(partner_id: user.partner.id)
      elsif user&.operator?
        # Оператор видит только себя
        scope.where(id: user.operator&.id)
      else
        scope.none
      end
    end
  end
end 