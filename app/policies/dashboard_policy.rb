class DashboardPolicy < ApplicationPolicy
  def show?
    # Все авторизованные пользователи могут видеть дашборд
    user.present?
  end
end 