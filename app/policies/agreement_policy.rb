# Политика доступа для управления договоренностями
class AgreementPolicy < ApplicationPolicy
  # Псевдоним для PartnerSupplierAgreement
  def self.policy_scope_for(scope, user)
    PartnerSupplierAgreementPolicy.new(user, scope).resolve
  end

  def index?
    user&.admin? || user&.manager?
  end

  def show?
    user&.admin? || user&.manager?
  end

  def create?
    user&.admin? || user&.manager?
  end

  def update?
    user&.admin? || user&.manager?
  end

  def destroy?
    user&.admin? || user&.manager?
  end

  def partners?
    index?
  end

  def suppliers?
    index?
  end

  class Scope < Scope
    def resolve
      if user&.admin? || user&.manager?
        # Админы и менеджеры видят все договоренности
        scope.all
      else
        # Остальные пользователи не имеют доступа к этому интерфейсу
        scope.none
      end
    end
  end
end