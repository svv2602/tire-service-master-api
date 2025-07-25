class SystemLogPolicy < ApplicationPolicy
  # Базовые права доступа к аудит логам
  def index?
    user&.admin? || user&.manager?
  end

  def show?
    user&.admin? || user&.manager?
  end

  def stats?
    index?
  end

  def export?
    user&.admin? || user&.manager?
  end

  # Скоуп для ограничения видимых логов
  class Scope < Scope
    def resolve
      return scope.none unless user&.admin? || user&.manager?
      
      if user&.admin?
        # Админы видят все логи
        scope.all
      elsif user&.manager?
        # Менеджеры видят все логи (у них есть доступ к аудиту)
        scope.all
      else
        scope.none
      end
    end
  end

  private

  def admin_or_manager?
    user&.admin? || user&.manager?
  end
end 