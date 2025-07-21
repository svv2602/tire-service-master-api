class EmailTemplatePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.none
      end
    end
  end

  def index?
    admin?
  end

  def show?
    admin?
  end

  def create?
    admin?
  end

  def update?
    admin?
  end

  def destroy?
    admin? && can_delete?
  end

  def toggle_status?
    admin?
  end

  def preview?
    admin?
  end

  def test_send?
    admin?
  end

  private

  def admin?
    user&.admin?
  end

  def can_delete?
    # Можно добавить логику для предотвращения удаления критически важных шаблонов
    # Например, не разрешать удаление системных шаблонов
    
    # Список критически важных шаблонов, которые нельзя удалять
    critical_templates = %w[
      booking_confirmation
      booking_cancellation
      admin_new_booking
    ]
    
    !critical_templates.include?(record.template_type)
  end
end 