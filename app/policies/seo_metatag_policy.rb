class SeoMetatagPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.all
    end
  end

  def index?
    true # Любой может просматривать метатеги
  end

  def show?
    true # Любой может просматривать отдельные метатеги
  end

  def create?
    user&.admin?
  end

  def update?
    user&.admin?
  end

  def destroy?
    user&.admin?
  end

  def analytics?
    user&.admin?
  end

  def create_defaults?
    user&.admin?
  end
end
