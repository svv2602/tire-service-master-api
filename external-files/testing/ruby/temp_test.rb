#!/usr/bin/env ruby

require_relative 'config/environment'

puts "Testing ServiceCategory model..."
puts "Count: #{ServiceCategory.count}"

# Test creating a category
category = ServiceCategory.create!(name: "Test Category #{Time.now.to_i}")
puts "Created category: #{category.name}"

# Test destroying
category.destroy!
puts "Destroyed category successfully"

puts "All tests passed!"
