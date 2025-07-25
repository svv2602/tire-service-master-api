class ServicePointPolicy < ApplicationPolicy
  include OptimizedPolicy
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
    return true if cached_user_data[:is_admin]
    return belongs_to_user_partner?(record.partner_id) if cached_user_data[:is_partner]
    return can_access_service_point?(record.id) if cached_user_data[:is_manager]
    false
  end

  def destroy?
    return true if cached_user_data[:is_admin]
    return belongs_to_user_partner?(record.partner_id) if cached_user_data[:is_partner]
    false
  end

  def nearby?
    true # Публичный доступ к поиску ближайших сервисных точек
  end

  def basic?
    true # Публичный доступ к базовой информации о сервисной точке
  end

  class Scope < Scope
    include OptimizedPolicy
    
        def resolve
      # Используем оптимизированный scope
            optimized_scope_for_service_points(scope)
    end
  end
end
end
