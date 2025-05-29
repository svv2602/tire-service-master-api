class ServicePointPolicy < ApplicationPolicy
  def index?
    true # Публичный доступ к списку сервисных точек
  end

  def show?
    true # Публичный доступ к просмотру сервисной точки
  end

  def create?
    user&.admin? || user&.partner?
  end

  def update?
    user&.admin? || (user&.partner? && record.partner_id == user.partner&.id) || 
      (user&.manager? && user.manager&.service_points&.include?(record))
  end

  def destroy?
    user&.admin? || (user&.partner? && record.partner_id == user.partner&.id)
  end

  def nearby?
    true # Публичный доступ к поиску ближайших сервисных точек
  end

  def basic?
    true # Публичный доступ к базовой информации о сервисной точке
  end

  class Scope < Scope
    def resolve
      if user.nil? || user.client?
        scope.active
      elsif user.admin?
        scope.all
      elsif user.partner?
        scope.by_partner(user.partner&.id)
      elsif user.manager?
        # Use a join to find service points associated with this manager
        if user.manager&.id
          scope.joins(:manager_service_points)
               .where(manager_service_points: { manager_id: user.manager.id })
               .distinct
        else
          scope.none
        end
      else
        scope.none
      end
    end
  end
end
