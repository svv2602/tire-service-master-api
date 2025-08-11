#!/usr/bin/env ruby
require_relative '../../config/environment'

puts "🔍 Анализ намерения для украинского запроса"

service = TireChatService.new(locale: 'uk')
intent = service.send(:analyze_simple_intent, 'дешеві на літо')

puts "Intent: #{intent}"
puts "Type: #{intent[:type]}"
puts "Parameters: #{intent[:parameters]}"
puts "Intent types: #{intent[:intent_types]}"

puts "\n" + "-" * 40

# Проверим также украинские слова в regex
puts "Проверка регулярных выражений:"
msg = 'дешеві на літо'.downcase

puts "Содержит 'дешев': #{msg.match?(/дешев|дешёв|бюджет|недорог|эконом|экономн|дёшев|cheap|budget/i)}"
puts "Содержит 'літ': #{msg.match?(/летн|літн|лето|літо|summer/i)}"