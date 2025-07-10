class ClientFavoritePointPolicy < ApplicationPolicy
  def index?
    user&.admin? || user&.client == record
  end

  def show?
    user&.admin? || user&.client == record
  end

  def create?
    user&.admin? || user&.client == record
  end

  def update?
    user&.admin? || user&.client == record
  end

  def destroy?
    user&.admin? || user&.client == record
  end

  def check_availability?
    user&.admin? || user&.client == record
  end

  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      elsif user&.client?
        scope.where(client: user.client)
      else
        scope.none
      end
    end
  end
end 