class BookingPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    return false unless user.present?
    
    if user.admin?
      true
    elsif user.partner?
      record.service_point.partner_id == user.partner&.id
    elsif user.manager?
      user.manager&.service_points&.include?(record.service_point)
    elsif user.client?
      record.client_id == user.client&.id
    else
      false
    end
  end

  def create?
    user&.client? || user&.admin? || user&.partner? || user&.manager?
  end

  def update?
    return false unless user.present?
    
    if user.admin?
      true
    elsif user.partner?
      record.service_point.partner_id == user.partner&.id
    elsif user.manager?
      user.manager&.service_points&.include?(record.service_point)
    elsif user.client?
      record.client_id == user.client&.id && record.status&.name == "pending"
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
      ["pending", "confirmed"].include?(record.status&.name)
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
    def resolve
      return scope.none unless user.present?
      
      if user.admin?
        scope.all
      elsif user.partner?
        scope.joins(:service_point).where(service_points: { partner_id: user.partner&.id })
      elsif user.manager?
        if user.manager&.service_point_ids.present?
          scope.joins(:service_point).where(service_points: { id: user.manager.service_point_ids })
        else
          scope.none
        end
      elsif user.client?
        if user.client.present?
          scope.where(client_id: user.client.id)
        else
          scope.none
        end
      else
        scope.none
      end
    end
  end
end
