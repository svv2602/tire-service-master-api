class CarTypePolicy < ApplicationPolicy
  def index?
    true # Anyone can see the list of car types
  end
  
  def show?
    true # Anyone can see car type details
  end
  
  def create?
    user && (user.admin? || user.partner?)
  end
  
  def update?
    user && (user.admin? || user.partner?)
  end
  
  def destroy?
    user && user.admin?
  end
  
  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
