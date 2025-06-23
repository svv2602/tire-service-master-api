#!/usr/bin/env ruby

begin
  puts "=== Тестирование создания сервисной точки ==="
  
  # Проверяем партнеров
  puts "Количество партнеров: #{Partner.count}"
  
  if Partner.count == 0
    puts "ОШИБКА: Нет партнеров в базе данных!"
    exit 1
  end
  
  # Берем первого партнера
  partner = Partner.first
  puts "Используем партнера: #{partner.company_name} (ID: #{partner.id})"
  
  # Проверяем существующие сервисные точки
  puts "Текущие сервисные точки партнера:"
  partner.service_points.each do |sp|
    puts "  - ID: #{sp.id}, Название: #{sp.name}"
  end
  
  # Проверяем максимальный ID в таблице service_points
  max_id = ServicePoint.maximum(:id) || 0
  puts "Максимальный ID сервисной точки: #{max_id}"
  
  # Создаем новую сервисную точку
  puts "\nСоздаем новую сервисную точку..."
  
  service_point = partner.service_points.create!(
    name: "Тестовая точка #{Time.now.to_i}",
    address: "ул. Тестовая, 1",
    contact_phone: "+380501234567",
    city_id: 1,
    is_active: true,
    work_status: "working"
  )
  
  puts "✅ УСПЕШНО! Создана сервисная точка:"
  puts "   ID: #{service_point.id}"
  puts "   Название: #{service_point.name}"
  puts "   Партнер ID: #{service_point.partner_id}"
  
rescue => e
  puts "❌ ОШИБКА: #{e.message}"
  puts "Тип ошибки: #{e.class}"
  puts "Детали:"
  puts e.backtrace[0..5].join("\n")
end
