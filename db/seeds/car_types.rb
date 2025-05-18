# Create car types
puts "Creating car types..."
car_types = [
  { name: 'Sedan', description: 'A standard passenger car with a separate trunk', is_active: true },
  { name: 'Hatchback', description: 'A car with a rear door that opens upward, similar to a sedan but with a trunk integrated into the passenger compartment', is_active: true },
  { name: 'SUV', description: 'Sport Utility Vehicle, combines features of road-going passenger cars with off-road vehicles', is_active: true },
  { name: 'Crossover', description: 'A vehicle with the design elements of an SUV but based on a passenger car platform', is_active: true },
  { name: 'Pickup', description: 'A light-duty truck with an open cargo area in the rear', is_active: true },
  { name: 'Minivan', description: 'A van designed for passenger use, with two or three rows of seating', is_active: true },
  { name: 'Coupe', description: 'A two-door car with a fixed roof and sloping rear', is_active: true },
  { name: 'Convertible', description: 'A car with a folding or removable roof', is_active: true },
  { name: 'Wagon', description: 'A car with an extended cargo area, similar to a hatchback but with more cargo space', is_active: true },
  { name: 'Van', description: 'A type of road vehicle used for transporting goods or people', is_active: true }
]

car_types.each do |car_type|
  CarType.find_or_create_by(name: car_type[:name]) do |ct|
    ct.description = car_type[:description]
    ct.is_active = car_type[:is_active]
  end
end
