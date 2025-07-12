class BookingConflictPolicy < ApplicationPolicy
  def index?
    user&.admin? || user&.partner?
  end

  def show?
    return false unless user&.admin? || user&.partner?
    
    # Партнеры могут видеть только конфликты своих сервисных точек
    if user.partner?
      partner_service_points = user.partner.service_points
      return partner_service_points.include?(record.booking.service_point)
    end
    
    true
  end

  def create?
    user&.admin?
  end

  def update?
    user&.admin? || user&.partner?
  end

  def destroy?
    user&.admin?
  end

  def resolve?
    show?
  end

  def ignore?
    show?
  end

  def analyze?
    user&.admin? || user&.partner?
  end

  def preview?
    user&.admin? || user&.partner?
  end

  def bulk_resolve?
    user&.admin? || user&.partner?
  end

  def statistics?
    user&.admin? || user&.partner?
  end

  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      elsif user&.partner?
        # Партнеры видят только конфликты своих сервисных точек
        service_point_ids = user.partner.service_points.pluck(:id)
        scope.joins(booking: :service_point)
             .where(bookings: { service_point_id: service_point_ids })
      else
        scope.none
      end
    end
  end
end 