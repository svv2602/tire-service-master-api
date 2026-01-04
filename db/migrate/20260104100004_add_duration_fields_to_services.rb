class AddDurationFieldsToServices < ActiveRecord::Migration[8.0]
  def change
    add_column :services, :base_duration_minutes, :integer, default: 30
    add_column :services, :duration_by_car_type, :jsonb, default: {}

    # Duration by car type format:
    # {
    #   "sedan": 30,
    #   "suv": 45,
    #   "crossover": 40,
    #   "minivan": 50,
    #   "truck": 60
    # }
  end
end
