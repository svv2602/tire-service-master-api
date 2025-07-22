class TelegramSettingPolicy < ApplicationPolicy
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

  def test_message?
    admin?
  end

  def set_webhook?
    admin?
  end

  def webhook_info?
    admin?
  end

  private

  def admin?
    user&.admin?
  end
end 