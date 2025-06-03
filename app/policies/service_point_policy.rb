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
        # Неаутентифицированные пользователи и клиенты видят только активные работающие точки
        scope.available_for_booking
      elsif user.admin?
        # Админы видят все точки
        scope.all
      elsif user.partner?
        # Партнеры видят только свои точки (в любом состоянии)
        scope.by_partner(user.partner&.id)
      elsif user.manager?
        # Менеджеры видят точки, к которым у них есть доступ
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
