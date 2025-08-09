# Политика доступа для правил вознаграждений
class RewardRulePolicy < ApplicationPolicy
  # Скоуп для фильтрации записей в зависимости от роли пользователя
  class Scope < Scope
    def resolve
      if user.admin?
        # Администраторы видят все правила
        scope.all
      elsif user.partner?
        # Партнеры видят только правила своих договоренностей
        scope.joins(:partner_supplier_agreement)
             .where(partner_supplier_agreements: { partner: user.partner })
      else
        # Остальные пользователи не имеют доступа
        scope.none
      end
    end
  end
  
  def index?
    user.admin? || user.partner?
  end
  
  def show?
    user.admin? || partner_owns_rule?
  end
  
  def create?
    return false unless user.admin? || user.partner?
    
    # Проверяем права на договоренность
    agreement = record.try(:partner_supplier_agreement) || 
                PartnerSupplierAgreement.find_by(id: params[:agreement_id])
    
    return false unless agreement
    
    user.admin? || (user.partner? && agreement.partner == user.partner)
  end
  
  def update?
    return false unless show?
    
    # Можно редактировать только активные правила активных договоренностей
    record.active? && record.partner_supplier_agreement.can_be_edited?
  end
  
  def destroy?
    return false unless show?
    
    # Администраторы могут удалять любые правила
    return true if user.admin?
    
    # Партнеры могут удалять только свои правила, если нет связанных вознаграждений
    partner_owns_rule? && record.partner_rewards.empty?
  end
  
  def preview?
    show?
  end
  
  def rule_types?
    user.admin? || user.partner?
  end
  
  private
  
  def partner_owns_rule?
    user.partner? && 
    record.partner_supplier_agreement.partner == user.partner
  end
end