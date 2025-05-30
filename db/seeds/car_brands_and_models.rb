# Очищаем существующие данные
puts 'Cleaning car brands and models...'
CarModel.delete_all
CarBrand.delete_all

# Создаем бренды и модели
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
  puts "Creating brand: #{brand_data[:name]}"
  brand = CarBrand.create!(
    name: brand_data[:name],
    is_active: true
  )

  brand_data[:models].each do |model_name|
    puts "  - Creating model: #{model_name}"
    brand.car_models.create!(
      name: model_name,
      is_active: true
    )
  end
end

puts "Created #{CarBrand.count} brands and #{CarModel.count} models" 