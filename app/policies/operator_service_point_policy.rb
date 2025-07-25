class OperatorServicePointPolicy < ApplicationPolicy
  # Базовые права доступа
  def show?
    return true if user&.admin? || user&.manager?
    return true if user&.partner? && owns_operator?
    return true if user&.operator? && is_own_assignment?
    false
  end

  def create?
    return true if user&.admin? || user&.manager?
    return true if user&.partner? && owns_operator?
    false
  end

  def update?
    return true if user&.admin? || user&.manager?
    return true if user&.partner? && owns_operator?
    false
  end

  def destroy?
    return true if user&.admin? || user&.manager?
    return true if user&.partner? && owns_operator?
    false
  end

  # Скоуп для ограничения видимых записей
  class Scope < Scope
    def resolve
      return scope.all if user&.admin? || user&.manager?
      
      if user&.partner?
        # Партнер видит привязки только своих операторов
        partner_id = user.partner.id
        scope.joins(operator: :partner)
             .where(operators: { partner_id: partner_id })
      elsif user&.operator?
        # Оператор видит только свои привязки
        operator_id = user.operator.id
        scope.where(operator_id: operator_id)
      else
        scope.none
      end
    end
  end

  private

  def owns_operator?
    return false unless user&.partner? && record.respond_to?(:operator)
    
    if record.is_a?(OperatorServicePoint)
      record.operator.partner_id == user.partner.id
    elsif record.is_a?(Operator)
      record.partner_id == user.partner.id
    else
      false
    end
  end

  def is_own_assignment?
    return false unless user&.operator? && record.is_a?(OperatorServicePoint)
    
    record.operator_id == user.operator.id
  end
end 