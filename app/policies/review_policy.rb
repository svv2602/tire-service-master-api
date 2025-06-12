class ReviewPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      elsif user&.client?
        scope.where(client: user.client)
      else
        scope.published
      end
    end
  end

  def index?
    true
  end

  def show?
    true
  end

  def create?
    return false unless user&.client?
    record.client == user.client
  end

  def update?
    return true if user&.admin?
    return false unless user&.client?
    record.client == user.client && record.created_at > 48.hours.ago
  end

  def destroy?
    return true if user&.admin?
    return false unless user&.client?
    record.client == user.client && record.created_at > 24.hours.ago
  end
end 