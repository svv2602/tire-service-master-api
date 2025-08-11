#!/usr/bin/env ruby
# Тест API чата с группировкой через HTTP запрос

require 'net/http'
require 'json'
require 'uri'

puts "🧪 Тестирование API чата с группировкой рекомендаций"
puts "=" * 60

# Настройки
api_url = 'http://localhost:8000/api/v1/tire_chat/message'
test_messages = [
  {
    message: "Зимние шины",
    description: "Быстрый вопрос - зимние шины"
  },
  {
    message: "195 65 на 15", 
    description: "Размер шин 195/65R15"
  }
]

def send_chat_message(url, message, conversation_id = nil, is_quick_question = false)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  
  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'
  
  body = {
    message: message,
    locale: 'ru',
    is_quick_question: is_quick_question
  }
  
  body[:conversation_id] = conversation_id if conversation_id
  
  request.body = body.to_json
  
  response = http.request(request)
  
  {
    status: response.code,
    body: JSON.parse(response.body),
    headers: response.to_hash
  }
rescue => e
  puts "❌ Ошибка запроса: #{e.message}"
  nil
end

conversation_id = nil

test_messages.each_with_index do |test_case, index|
  puts "\n#{index + 1}. #{test_case[:description]}: '#{test_case[:message]}'"
  
  is_quick_question = index == 0 # Первое сообщение - быстрый вопрос
  
  result = send_chat_message(
    api_url, 
    test_case[:message], 
    conversation_id,
    is_quick_question
  )
  
  if result
    puts "   HTTP Статус: #{result[:status]}"
    
    if result[:body]['success']
      response_data = result[:body]['response']
      conversation_id = result[:body]['conversation_id']
      
      puts "   Ответ AI: #{response_data['message'][0..200]}..." if response_data['message']
      
      if response_data['recommendations']
        puts "   📊 Рекомендации найдены: #{response_data['recommendations'].length}"
        
        response_data['recommendations'].each_with_index do |rec, rec_index|
          puts "      #{rec_index + 1}. #{rec['brand']} #{rec['model']} - #{rec['price']} грн"
        end
      else
        puts "   📊 Рекомендации не найдены"
      end
      
      puts "   🔗 Conversation ID: #{conversation_id}"
      
    else
      puts "   ❌ Ошибка API: #{result[:body]['error']}"
    end
  end
end

puts "\n" + "=" * 60
puts "🎯 Тестирование API завершено"