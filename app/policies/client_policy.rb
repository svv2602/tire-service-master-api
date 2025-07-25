class ClientPolicy < ApplicationPolicy
  def index?
    user&.admin? || user&.partner? || user&.manager?
  end

  def show?
    return true if user&.admin? || user&.manager?
    return true if user.present? && user.id == record.user_id # Сам клиент
    
    # Партнер может видеть только клиентов, которые делали бронирования в его точках
    if user&.partner?
      return record.bookings.joins(:service_point).where(service_points: { partner_id: user.partner.id }).exists?
    end
    
    false
  end

  def create?
    user&.admin?
  end

  def update?
    return true if user&.admin?
    return true if user.present? && user.id == record.user_id # Сам клиент
    
    # Партнер может редактировать только клиентов, которые делали бронирования в его точках
    if user&.partner?
      return record.bookings.joins(:service_point).where(service_points: { partner_id: user.partner.id }).exists?
    end
    
    false
  end

  def destroy?
    return true if user&.admin?
    return true if user.present? && user.id == record.user_id # Сам клиент
    
    # Партнеры не могут удалять клиентов
    false
  end

  class Scope < Scope
    def resolve
      return scope.none unless user.present?
      
      if user.admin? || user.manager?
        # Админы и менеджеры видят всех клиентов
        scope.all
      elsif user.client?
        # Клиент видит только себя
        scope.where(id: user.client&.id)
      elsif user.partner?
        # Партнер видит только клиентов, которые делали бронирования в его точках
        scope.joins(:bookings)
             .joins('JOIN service_points ON bookings.service_point_id = service_points.id')
             .where('service_points.partner_id = ?', user.partner.id)
             .distinct
      else
        scope.none
      end
    end
  end
end
