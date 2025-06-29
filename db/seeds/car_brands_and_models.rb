# Создаем бренды и модели (безопасно, без удаления существующих)
puts 'Creating car brands and models...'

brands_data = [
  {
    name: 'Toyota',
    models: ['Camry', 'Corolla', 'RAV4', 'Land Cruiser', 'Prius']
  },
  {
    name: 'Honda',
    models: ['Civic', 'Accord', 'CR-V', 'Pilot', 'HR-V']
  },
  {
    name: 'Volkswagen',
    models: ['Golf', 'Passat', 'Tiguan', 'Polo', 'Touareg']
  },
  {
    name: 'BMW',
    models: ['3 Series', '5 Series', 'X3', 'X5', '7 Series']
  },
  {
    name: 'Mercedes-Benz',
    models: ['C-Class', 'E-Class', 'GLC', 'S-Class', 'GLE']
  }
]

brands_data.each do |brand_data|
  puts "Creating/updating brand: #{brand_data[:name]}"
  brand = CarBrand.find_or_create_by(name: brand_data[:name]) do |b|
    b.is_active = true
  end

  brand_data[:models].each do |model_name|
    puts "  - Creating/updating model: #{model_name}"
    brand.car_models.find_or_create_by(name: model_name) do |m|
      m.is_active = true
    end
  end
end

puts "Created #{CarBrand.count} brands and #{CarModel.count} models" 