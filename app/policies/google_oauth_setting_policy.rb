class GoogleOauthSettingPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.none
      end
    end
  end

  def show?
    admin?
  end

  def update?
    admin?
  end

  def test_connection?
    admin?
  end

  def authorization_url?
    admin?
  end

  private

  def admin?
    user&.admin?
  end
end 