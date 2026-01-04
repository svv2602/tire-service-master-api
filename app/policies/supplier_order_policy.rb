class SupplierOrderPolicy < ApplicationPolicy
  def index?
    supplier_access?
  end

  def show?
    supplier_access? && order_belongs_to_supplier?
  end

  def update?
    supplier_access? && order_belongs_to_supplier? && record.active_status?
  end

  def confirm?
    supplier_access? && order_belongs_to_supplier? && record.submitted?
  end

  def start_processing?
    supplier_access? && order_belongs_to_supplier? && record.confirmed?
  end

  def ship?
    supplier_access? && order_belongs_to_supplier? && record.processing?
  end

  def deliver?
    supplier_access? && order_belongs_to_supplier? && record.shipped?
  end

  def complete?
    supplier_access? && order_belongs_to_supplier? && (record.processing? || record.delivered?)
  end

  def cancel?
    supplier_access? && order_belongs_to_supplier? && record.can_be_cancelled_by_admin?
  end

  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      elsif user.supplier?
        scope.where(supplier: user.supplier)
      else
        scope.none
      end
    end
  end

  private

  def supplier_access?
    user.admin? || user.supplier?
  end

  def order_belongs_to_supplier?
    return true if user.admin?
    return false unless user.supplier?

    record.supplier_id == user.supplier.id
  end
end
