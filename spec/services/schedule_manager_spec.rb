require 'rails_helper'

# SKIP: Этот сервис больше не используется
# Мы перешли на динамическую систему доступности (DynamicAvailabilityService)
RSpec.describe ScheduleManager, type: :service do
  skip "Весь ScheduleManager больше не используется" do
    pending "Заменен на DynamicAvailabilityService - генерация слотов отменена"
  end
end 