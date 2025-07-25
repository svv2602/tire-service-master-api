class ReviewPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user&.admin? || user&.manager?
        # Админы и менеджеры видят все отзывы
        scope.all
      elsif user&.partner?
        # Партнер видит только отзывы о своих сервисных точках
        scope.joins(:service_point).where(service_points: { partner_id: user.partner.id })
      elsif user&.client?
        # Клиент видит только свои отзывы
        scope.where(client: user.client)
      else
        # Неавторизованные пользователи видят только опубликованные отзывы
        scope.published
      end
    end
  end

  def index?
    true
  end

  def show?
    return true if user&.admin? || user&.manager?
    return true if user&.client? && record.client == user.client
    
    # Партнер может видеть отзывы только о своих точках
    if user&.partner?
      return record.service_point.partner_id == user.partner.id
    end
    
    # Неавторизованные пользователи видят только опубликованные отзывы
    record.is_published?
  end

  def create?
    # Администратор может создавать отзывы для любых клиентов
    return true if user&.admin?
    
    # Клиент может создавать отзывы только для себя
    return false unless user&.client?
    record.client == user.client
  end

  def update?
    return true if user&.admin?
    
    # Партнер может редактировать отзывы о своих точках (например, отвечать на них)
    if user&.partner?
      return record.service_point.partner_id == user.partner.id
    end
    
    # Клиент может редактировать свои отзывы в течение 48 часов
    return false unless user&.client?
    record.client == user.client && record.created_at > 48.hours.ago
  end

  def destroy?
    return true if user&.admin?
    
    # Партнеры не могут удалять отзывы
    
    # Клиент может удалять свои отзывы в течение 24 часов
    return false unless user&.client?
    record.client == user.client && record.created_at > 24.hours.ago
  end
end 