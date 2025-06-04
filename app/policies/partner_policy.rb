class PartnerPolicy < ApplicationPolicy
  # Основные действия с партнерами
  def index?
    user.admin? || user.partner?
  end

  def show?
    user.admin? || (user.partner? && user.partner == record)
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

  # Специфичные действия для сервисных точек
  def create_service_point?
    user.admin? || (user.partner? && user.partner == record)
  end

  def manage_service_points?
    user.admin? || (user.partner? && user.partner == record)
  end

  # Scope для списка партнеров
  class Scope < Scope
    def resolve
      if user.admin?
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