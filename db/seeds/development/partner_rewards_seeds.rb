# Сиды для системы вознаграждений партнеров
puts "🎯 Создание тестовых данных для системы вознаграждений партнеров..."

# Найдем первого партнера и поставщика
partner = Partner.active.first
supplier = Supplier.active.first

if partner && supplier
  puts "📋 Создание договоренности между #{partner.company_name} и #{supplier.name}..."
  
  # Создаем договоренность
  agreement = PartnerSupplierAgreement.find_or_create_by!(
    partner: partner,
    supplier: supplier
  ) do |a|
    a.start_date = 1.month.ago
    a.end_date = nil # Бессрочно
    a.commission_type = 'custom'
    a.active = true
    a.description = 'Индивидуальные условия по вознаграждениям'
  end
  
  puts "✅ Договоренность создана: #{agreement.display_name}"
  
  # Создаем правила вознаграждений
  
  # 1. Общее правило - 5% от суммы заказа
  general_rule = RewardRule.find_or_create_by!(
    partner_supplier_agreement: agreement,
    rule_type: 'percentage',
    priority: 100
  ) do |r|
    r.amount = 5.0
    r.conditions = {}.to_json
    r.active = true
    r.description = 'Общий процент от всех заказов'
  end
  
  puts "✅ Общее правило: #{general_rule.amount_display} от всех заказов"
  
  # 2. Специальное правило для бренда "Росава" - фиксированно 50 грн за единицу
  special_rule = RewardRule.find_or_create_by!(
    partner_supplier_agreement: agreement,
    rule_type: 'fixed_per_item',
    priority: 10
  ) do |r|
    r.amount = 50.0
    r.conditions = {
      'brands' => ['Росава', 'ROSAVA'],
      'exclude_brands' => false,
      'description' => 'Специальные условия для бренда Росава'
    }.to_json
    r.active = true
    r.description = 'Фиксированная ставка для шин Росава'
  end
  
  puts "✅ Специальное правило: #{special_rule.amount_display} за единицу шин Росава"
  
  # 3. Правило по диаметрам 15-16 - исключение из общего правила
  diameter_rule = RewardRule.find_or_create_by!(
    partner_supplier_agreement: agreement,
    rule_type: 'fixed_per_item',
    priority: 20
  ) do |r|
    r.amount = 30.0
    r.conditions = {
      'diameters' => ['15', '16'],
      'exclude_diameters' => false,
      'min_order_amount' => 1000,
      'description' => 'Сниженная ставка для маленьких диаметров'
    }.to_json
    r.active = true
    r.description = 'Уменьшенная ставка для диаметров 15-16'
  end
  
  puts "✅ Правило по диаметрам: #{diameter_rule.amount_display} за единицу R15-R16"
  
  # 4. Бонусное правило за крупные заказы
  bonus_rule = RewardRule.find_or_create_by!(
    partner_supplier_agreement: agreement,
    rule_type: 'fixed_per_order',
    priority: 5
  ) do |r|
    r.amount = 500.0
    r.conditions = {
      'min_order_amount' => 10000,
      'description' => 'Бонус за крупные заказы свыше 10000 грн'
    }.to_json
    r.active = true
    r.description = 'Дополнительный бонус за крупные заказы'
  end
  
  puts "✅ Бонусное правило: #{bonus_rule.amount_display} за заказы свыше 10000 грн"
  
  puts "🎉 Создано правил вознаграждений: #{agreement.reward_rules.count}"
  
else
  puts "⚠️  Не найдены активные партнеры или поставщики для создания тестовых данных"
end

puts "✅ Сиды для системы вознаграждений завершены!"