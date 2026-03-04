# Authorization policy for webhook endpoint management.
# Only the owning partner and admins can manage webhook endpoints.
class WebhookEndpointPolicy < ApplicationPolicy
  def index?
    user.admin? || user.partner?
  end

  def show?
    user.admin? || owns_endpoint?
  end

  def create?
    user.admin? || user.partner?
  end

  def update?
    user.admin? || owns_endpoint?
  end

  def destroy?
    user.admin? || owns_endpoint?
  end

  def test?
    user.admin? || owns_endpoint?
  end

  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      elsif user.partner?
        scope.where(partner: user.partner)
      else
        scope.none
      end
    end
  end

  private

  def owns_endpoint?
    user.partner? && record.partner_id == user.partner&.id
  end
end
