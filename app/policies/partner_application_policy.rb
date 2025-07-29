class PartnerApplicationPolicy < ApplicationPolicy
  # Просмотр списка заявок - только админы и менеджеры
  def index?
    user&.admin? || user&.manager?
  end

  # Просмотр конкретной заявки - только админы и менеджеры
  def show?
    user&.admin? || user&.manager?
  end

  # Создание заявки - публичный доступ (для потенциальных партнеров)
  def create?
    true
  end

  # Обновление заявки (заметки админа) - только админы и менеджеры
  def update?
    user&.admin? || user&.manager?
  end

  # Изменение статуса заявки - только админы и менеджеры
  def update_status?
    user&.admin? || user&.manager?
  end

  # Удаление заявки - только админы
  def destroy?
    user&.admin?
  end

  # Массовые операции - только админы
  def bulk_update?
    user&.admin?
  end

  # Экспорт данных - только админы и менеджеры
  def export?
    user&.admin? || user&.manager?
  end

  # Скоуп для фильтрации записей в зависимости от роли пользователя
  class Scope < Scope
    def resolve
      if user&.admin? || user&.manager?
        # Админы и менеджеры видят все заявки
        scope.all
      else
        # Остальные пользователи не имеют доступа к заявкам
        scope.none
      end
    end
  end

  private

  # Проверка, может ли пользователь обрабатывать заявку
  def can_process_application?
    record.can_be_processed_by?(user)
  end
end 