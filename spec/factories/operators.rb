FactoryBot.define do
  factory :operator do
    user do
      operator_role = UserRole.find_or_create_by!(name: 'operator') do |r|
        r.description = 'Оператор сервисной точки'
        r.is_active = true
      end
      FactoryBot.create(:user, role_id: operator_role.id)
    end
    position { 'Старший оператор' }
    access_level { 1 }
    is_active { true }
  end
end
