class BookingPolicy < ApplicationPolicy
  include OptimizedPolicy
  def index?
    user.present?
  end

  def show?
    return false unless user.present?
    return true if cached_user_data[:is_admin]
    
    if cached_user_data[:is_partner]
      return belongs_to_user_partner?(record.service_point.partner_id)
    elsif cached_user_data[:is_manager] || cached_user_data[:is_operator]
      return can_access_service_point?(record.service_point_id)
    elsif cached_user_data[:is_client]
      return record.client_id == cached_user_data[:client_id]
    end
    
    false
  end

  def create?
    user&.client? || user&.admin? || user&.partner? || user&.manager?
  end

  def update?
    return false unless user.present?
    return true if cached_user_data[:is_admin]
    
    if cached_user_data[:is_partner]
      return belongs_to_user_partner?(record.service_point.partner_id)
    elsif cached_user_data[:is_manager] || cached_user_data[:is_operator]
      return can_access_service_point?(record.service_point_id)
    elsif cached_user_data[:is_client]
      return record.client_id == cached_user_data[:client_id] && record.status == "pending"
    end
    
    false
  end

  def update_status?
    return false unless user.present?
    
    if user.admin?
      true
    elsif user.partner?
      record.service_point.partner_id == user.partner&.id
    elsif user.manager?
      user.manager&.service_points&.include?(record.service_point)
    else
      false
    end
  end

  def destroy?
    update?
  end

  def confirm?
    return false unless user.present?
    
    if user.admin?
      true
    elsif user.partner?
      record.service_point.partner_id == user.partner&.id
    elsif user.manager?
      user.manager&.service_points&.include?(record.service_point)
    else
      false
    end
  end

  def cancel?
    return false unless user.present?
    
    if user.admin?
      true
    elsif user.partner?
      record.service_point.partner_id == user.partner&.id
    elsif user.manager?
      user.manager&.service_points&.include?(record.service_point)
    elsif user.client?
      record.client_id == user.client&.id && 
      ["pending", "confirmed"].include?(record.status)
    else
      false
    end
  end

  def complete?
    return false unless user.present?
    
    if user.admin?
      true
    elsif user.partner?
      record.service_point.partner_id == user.partner&.id
    elsif user.manager?
      user.manager&.service_points&.include?(record.service_point)
    else
      false
    end
  end

  def no_show?
    confirm?
  end

  class Scope < Scope
    include OptimizedPolicy
    
    def resolve
      return scope.none unless user.present?
      
      # Используем оптимизированный scope
      optimized_scope_for_bookings(scope)
    end
  end
end
