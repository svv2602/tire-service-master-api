class ClientPolicy < ApplicationPolicy
  def index?
    user&.admin? || user&.partner? || user&.manager?
  end

  def show?
    user&.admin? || user&.partner? || user&.manager? || (user.present? && user.id == record.user_id)
  end

  def create?
    user&.admin?
  end

  def update?
    user&.admin? || (user.present? && user.id == record.user_id)
  end

  def destroy?
    user&.admin? || (user.present? && user.id == record.user_id)
  end

  class Scope < Scope
    def resolve
      return scope.none unless user.present?
      
      if user.admin?
        scope.all
      elsif user.client?
        scope.where(id: user.client&.id)
      elsif user.partner? || user.manager?
        # Partner and manager can see all clients as part of their dashboard
        scope.all
      else
        scope.none
      end
    end
  end
end
