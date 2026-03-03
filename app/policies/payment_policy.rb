# frozen_string_literal: true

class PaymentPolicy < ApplicationPolicy
  def index?
    true # All authenticated users can see their own payment history
  end

  def show?
    user.admin? || record.user_id == user.id
  end

  def refund_request?
    user.admin? || record.user_id == user.id
  end

  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(user_id: user.id)
      end
    end
  end
end
