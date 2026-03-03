class PartnerPolicy < ApplicationPolicy
  # Main actions with partners -- clients are explicitly denied
  def index?
    user.admin? || user.partner? || user.manager?
  end

  def show?
    user.admin? || user.manager? || (user.partner? && user.partner == record)
  end

  def create?
    user.admin?
  end

  def update?
    user.admin? || (user.partner? && user.partner == record)
  end

  def destroy?
    user.admin?
  end

  # Service point management actions
  def create_service_point?
    user.admin? || (user.partner? && user.partner == record)
  end

  def manage_service_points?
    user.admin? || (user.partner? && user.partner == record)
  end

  # Scope for partner list -- clients see nothing
  class Scope < Scope
    def resolve
      if user.admin? || user.manager?
        scope.all
      elsif user.partner?
        scope.where(id: user.partner.id)
      else
        scope.none
      end
    end
  end

  private

  def record
    @record
  end
end
