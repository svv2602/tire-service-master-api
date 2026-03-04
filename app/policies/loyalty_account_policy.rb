# Authorization policy for loyalty account access
class LoyaltyAccountPolicy < ApplicationPolicy
  def balance?
    true # Any authenticated user can view their own balance
  end

  def transactions?
    true # Any authenticated user can view their own transactions
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(user_id: user.id)
      end
    end
  end
end
