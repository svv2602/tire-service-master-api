#!/usr/bin/env ruby

require 'nokogiri'
require 'json'

# Читаем XML файл
xml_content = File.read('/home/snisar/mobi_tz/md/auto/items/hotline2.xml')
doc = Nokogiri::XML(xml_content)

puts "=== XML ОТЛАДКА ==="
puts "Всего товаров: #{doc.xpath('//item').count}"

# Анализируем первые 10 товаров
doc.xpath('//item').first(10).each_with_index do |item, index|
  puts "\n--- ТОВАР #{index + 1} ---"
  
  # Основные поля
  id = item.at_xpath('./id')&.text&.strip
  vendor = item.at_xpath('./vendor')&.text&.strip
  name = item.at_xpath('./name')&.text&.strip
  
  puts "ID: #{id}"
  puts "Vendor: #{vendor}"
  puts "Name: #{name}"
  
  # Параметры шины
  params = {}
  item.xpath('.//param').each do |param|
    param_name = param['name']&.strip
    value = param.text&.strip
    params[param_name] = value if param_name && value
  end
  
  tire_type = params['Тип']
  width = params['Ширина профілю шини, мм']&.to_i
  height = params['Висота профілю шини, %']&.to_i
  diameter = params['Внутрішній діаметр покришки, дюйми']
  
  puts "Тип: #{tire_type}"
  puts "Ширина: #{width}"
  puts "Высота: #{height}"
  puts "Диаметр: #{diameter}"
  
  # Проверяем валидность
  required_fields = [id, vendor, name, tire_type, width, height, diameter]
  missing_fields = []
  
  missing_fields << "id" if id.nil? || id.empty?
  missing_fields << "vendor" if vendor.nil? || vendor.empty?
  missing_fields << "name" if name.nil? || name.empty?
  missing_fields << "tire_type" if tire_type.nil? || tire_type.empty?
  missing_fields << "width" if width.nil? || width == 0
  missing_fields << "height" if height.nil? || height == 0
  missing_fields << "diameter" if diameter.nil? || diameter.empty?
  
  if missing_fields.any?
    puts "❌ ОШИБКА: Отсутствуют поля: #{missing_fields.join(', ')}"
  else
    puts "✅ Все обязательные поля присутствуют"
  end
  
  # Проверяем размеры
  if width && height && diameter
    width_valid = width.between?(125, 355)
    height_valid = height.between?(25, 95)
    diameter_valid = diameter.to_s.match?(/^\d{2}C?$/)
    
    puts "Ширина валидна: #{width_valid} (#{width})"
    puts "Высота валидна: #{height_valid} (#{height})"
    puts "Диаметр валиден: #{diameter_valid} (#{diameter})"
    
    unless width_valid && height_valid && diameter_valid
      puts "❌ Некорректные размеры шины"
    end
  end
end

puts "\n=== ОБЩАЯ СТАТИСТИКА ==="

# Подсчитаем типичные ошибки
total_items = doc.xpath('//item').count
missing_tire_type = 0
missing_width = 0
missing_height = 0
missing_diameter = 0
invalid_sizes = 0

doc.xpath('//item').each do |item|
  params = {}
  item.xpath('.//param').each do |param|
    param_name = param['name']&.strip
    value = param.text&.strip
    params[param_name] = value if param_name && value
  end
  
  tire_type = params['Тип']
  width = params['Ширина профілю шини, мм']&.to_i
  height = params['Висота профілю шини, %']&.to_i
  diameter = params['Внутрішній діаметр покришки, дюйми']
  
  missing_tire_type += 1 if tire_type.nil? || tire_type.empty?
  missing_width += 1 if width.nil? || width == 0
  missing_height += 1 if height.nil? || height == 0
  missing_diameter += 1 if diameter.nil? || diameter.empty?
  
  if width && height && diameter
    width_valid = width.between?(125, 355)
    height_valid = height.between?(25, 95)
    diameter_valid = diameter.to_s.match?(/^\d{2}C?$/)
    
    unless width_valid && height_valid && diameter_valid
      invalid_sizes += 1
    end
  end
end

puts "Всего товаров: #{total_items}"
puts "Без типа шины: #{missing_tire_type}"
puts "Без ширины: #{missing_width}"
puts "Без высоты: #{missing_height}"
puts "Без диаметра: #{missing_diameter}"
puts "С некорректными размерами: #{invalid_sizes}"

error_percent = ((missing_tire_type + missing_width + missing_height + missing_diameter + invalid_sizes).to_f / total_items * 100).round(2)
puts "Процент ошибок: #{error_percent}%"