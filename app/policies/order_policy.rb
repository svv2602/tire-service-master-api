class OrderPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      case user&.role&.name
      when 'admin'
        # Администраторы видят все заказы
        scope.all
      when 'partner'
        # Партнеры видят только заказы своих сервисных точек
        partner = user.partner
        return scope.none unless partner
        
        partner_service_point_ids = partner.service_points.pluck(:id)
        scope.where(service_point_id: partner_service_point_ids)
      when 'operator'
        # Операторы видят только заказы сервисных точек, к которым они привязаны
        operator_service_point_ids = user.operator_service_points
                                        .where(is_active: true)
                                        .pluck(:service_point_id)
        scope.where(service_point_id: operator_service_point_ids)
      when 'manager'
        # Менеджеры видят заказы сервисных точек своих партнеров
        manager_partner_ids = user.manager_service_points.pluck(:partner_id).uniq
        service_point_ids = ServicePoint.where(partner_id: manager_partner_ids).pluck(:id)
        scope.where(service_point_id: service_point_ids)
      else
        # Клиенты и неавторизованные пользователи не видят заказы
        scope.none
      end
    end
  end

  def index?
    user&.admin? || user&.partner? || user&.operator? || user&.manager?
  end

  def show?
    return true if user&.admin?
    
    case user&.role&.name
    when 'partner'
      # Партнер может видеть заказы своих сервисных точек
      partner = user.partner
      return false unless partner
      
      partner.service_points.pluck(:id).include?(record.service_point_id)
    when 'operator'
      # Оператор может видеть заказы сервисных точек, к которым привязан
      operator_service_point_ids = user.operator_service_points
                                      .where(is_active: true)
                                      .pluck(:service_point_id)
      operator_service_point_ids.include?(record.service_point_id)
    when 'manager'
      # Менеджер может видеть заказы сервисных точек своих партнеров
      manager_partner_ids = user.manager_service_points.pluck(:partner_id).uniq
      service_point_ids = ServicePoint.where(partner_id: manager_partner_ids).pluck(:id)
      service_point_ids.include?(record.service_point_id)
    else
      false
    end
  end

  def create?
    # Создавать заказы могут только администраторы или системные интеграции
    user&.admin?
  end

  def update?
    # Обновлять основные данные заказа могут только администраторы
    user&.admin?
  end

  def destroy?
    # Удалять заказы могут только администраторы
    user&.admin?
  end

  def mark_as_ready?
    return true if user&.admin?
    
    # Партнеры и операторы могут отмечать заказы как готовые
    case user&.role&.name
    when 'partner'
      partner = user.partner
      return false unless partner
      
      partner.service_points.pluck(:id).include?(record.service_point_id) && 
      record.can_mark_as_ready?
    when 'operator'
      operator_service_point_ids = user.operator_service_points
                                      .where(is_active: true)
                                      .pluck(:service_point_id)
      operator_service_point_ids.include?(record.service_point_id) && 
      record.can_mark_as_ready?
    when 'manager'
      manager_partner_ids = user.manager_service_points.pluck(:partner_id).uniq
      service_point_ids = ServicePoint.where(partner_id: manager_partner_ids).pluck(:id)
      service_point_ids.include?(record.service_point_id) && 
      record.can_mark_as_ready?
    else
      false
    end
  end

  def mark_as_delivered?
    return true if user&.admin?
    
    # Партнеры и операторы могут отмечать заказы как выданные
    case user&.role&.name
    when 'partner'
      partner = user.partner
      return false unless partner
      
      partner.service_points.pluck(:id).include?(record.service_point_id) && 
      record.can_mark_as_delivered?
    when 'operator'
      operator_service_point_ids = user.operator_service_points
                                      .where(is_active: true)
                                      .pluck(:service_point_id)
      operator_service_point_ids.include?(record.service_point_id) && 
      record.can_mark_as_delivered?
    when 'manager'
      manager_partner_ids = user.manager_service_points.pluck(:partner_id).uniq
      service_point_ids = ServicePoint.where(partner_id: manager_partner_ids).pluck(:id)
      service_point_ids.include?(record.service_point_id) && 
      record.can_mark_as_delivered?
    else
      false
    end
  end

  def cancel?
    return true if user&.admin?
    
    # Партнеры и операторы могут отменять заказы
    case user&.role&.name
    when 'partner'
      partner = user.partner
      return false unless partner
      
      partner.service_points.pluck(:id).include?(record.service_point_id) && 
      record.can_cancel?
    when 'operator'
      operator_service_point_ids = user.operator_service_points
                                      .where(is_active: true)
                                      .pluck(:service_point_id)
      operator_service_point_ids.include?(record.service_point_id) && 
      record.can_cancel?
    when 'manager'
      manager_partner_ids = user.manager_service_points.pluck(:partner_id).uniq
      service_point_ids = ServicePoint.where(partner_id: manager_partner_ids).pluck(:id)
      service_point_ids.include?(record.service_point_id) && 
      record.can_cancel?
    else
      false
    end
  end

  def add_note?
    # Добавлять заметки могут партнеры, операторы и менеджеры для своих заказов
    return true if user&.admin?
    
    case user&.role&.name
    when 'partner'
      partner = user.partner
      return false unless partner
      
      partner.service_points.pluck(:id).include?(record.service_point_id)
    when 'operator'
      operator_service_point_ids = user.operator_service_points
                                      .where(is_active: true)
                                      .pluck(:service_point_id)
      operator_service_point_ids.include?(record.service_point_id)
    when 'manager'
      manager_partner_ids = user.manager_service_points.pluck(:partner_id).uniq
      service_point_ids = ServicePoint.where(partner_id: manager_partner_ids).pluck(:id)
      service_point_ids.include?(record.service_point_id)
    else
      false
    end
  end

  def export?
    # Экспортировать могут партнеры, операторы, менеджеры и администраторы
    user&.admin? || user&.partner? || user&.operator? || user&.manager?
  end

  def stats?
    # Статистику могут просматривать партнеры, менеджеры и администраторы
    user&.admin? || user&.partner? || user&.manager?
  end

  private

  def owner?
    # Определяем, является ли пользователь "владельцем" заказа
    case user&.role&.name
    when 'partner'
      partner = user.partner
      return false unless partner
      
      partner.service_points.pluck(:id).include?(record.service_point_id)
    when 'operator'
      operator_service_point_ids = user.operator_service_points
                                      .where(is_active: true)
                                      .pluck(:service_point_id)
      operator_service_point_ids.include?(record.service_point_id)
    when 'manager'
      manager_partner_ids = user.manager_service_points.pluck(:partner_id).uniq
      service_point_ids = ServicePoint.where(partner_id: manager_partner_ids).pluck(:id)
      service_point_ids.include?(record.service_point_id)
    else
      false
    end
  end
end 