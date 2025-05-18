# frozen_string_literal: true

module AuthTestHelper
  # Метод для проверки ответа при ошибке авторизации
  def check_auth_response(response)
    puts "Response: #{response.status}"
    puts "Response body: #{response.body}"
    puts "Headers: #{response.headers.slice('Authorization', 'Content-Type')}"
    
    begin
      puts "Parsed JSON: #{JSON.parse(response.body)}"
    rescue => e
      puts "Error parsing JSON: #{e.message}"
    end
  end
end

# Подключаем хелпер к RSpec
RSpec.configure do |config|
  config.include AuthTestHelper, type: :request
end
