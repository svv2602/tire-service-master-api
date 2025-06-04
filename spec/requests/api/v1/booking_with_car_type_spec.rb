require 'rails_helper'

RSpec.describe "BookingWithCarType", type: :request do
  # SKIP: Этот тест использует старую логику со слотами
  # Мы перешли на динамическую систему доступности
  skip "creates a booking with a car type" do
    # Тест отключен - используется старая логика со schedule_slot
    # Новая система использует динамический расчет доступности без слотов
    pending "Переписать под динамическую систему доступности"
  end
end
