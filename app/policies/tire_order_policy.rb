class TireOrderPolicy < ApplicationPolicy
  # Основные права доступа
  def index?
    true # Пользователи видят только свои заказы (фильтрация в контроллере)
  end

  def index_all?
    user&.admin?
  end

  def show?
    user&.admin? || record.user == user
  end

  def create?
    user.present?
  end

  def update?
    false # Заказы не редактируются напрямую, только через специальные действия
  end

  def destroy?
    false # Заказы не удаляются, только отменяются или архивируются
  end

  # Специальные действия
  def confirm?
    user&.admin? && record.submitted?
  end

  def start_processing?
    user&.admin? && record.status == 'confirmed'
  end

  def complete?
    user&.admin? && record.status == 'processing'
  end

  def cancel?
    return false unless record.present?
    
    if user&.admin?
      record.can_be_cancelled_by_admin?
    else
      record.user == user && record.can_be_cancelled_by_user?
    end
  end

  def archive?
    record.user == user && record.can_be_archived?
  end

  # Скоуп для фильтрации записей
  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.where(user: user)
      end
    end
  end

  # Права для партнеров (если понадобится в будущем)
  def partner_access?
    user&.partner? && record.supplier.present?
  end

  private

  def user_owns_record?
    record.user == user
  end

  def admin_or_owner?
    user&.admin? || user_owns_record?
  end
end