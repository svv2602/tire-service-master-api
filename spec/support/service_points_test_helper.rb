module ServicePointsTestHelper
  # Метод для удаления всех сервисных точек перед тестом
  def clear_service_points
    ServicePoint.delete_all
  end
  
  # Enhanced method for creating authentication headers
  def generate_auth_headers(user)
    token = Auth::JsonWebToken.encode(user_id: user.id)
    { 
      'Authorization' => "Bearer #{token}", 
      'Content-Type' => 'application/json', 
      'Accept' => 'application/json' 
    }
  end
  
  # Helper method to generate JSON for request body
  def json_payload(data)
    data.to_json
  end
  
  # Методы для генерации уникальных имен
  def unique_name(prefix = "SP")
    "#{prefix}-#{Time.now.to_f}-#{SecureRandom.hex(4)}"
  end
  
  # Метод для создания сервисной точки с гарантированно уникальным именем
  def create_unique_service_point(attributes = {})
    default_attributes = {
      name: unique_name,
      address: Faker::Address.full_address,
      post_count: 1,
      default_slot_duration: 60
    }
    
    # Если партнер и город не указаны, создаем их автоматически
    default_attributes[:partner] ||= attributes[:partner] || create(:partner)
    default_attributes[:city] ||= attributes[:city] || create(:city, name: "City-#{Time.now.to_f}-#{SecureRandom.hex(4)}")
    
    # Используем существующие статусы вместо создания новых
    unless attributes[:status]
      status = ServicePointStatus.find_by(name: 'active')
      if status.nil?
        status = create(:service_point_status, name: 'active')
      end
      default_attributes[:status] = status
    end
    
    # Объединяем атрибуты по умолчанию с переданными
    create(:service_point, default_attributes.merge(attributes))
  end
  
  # Debug helper for authentication issues
  def check_auth_response(response)
    puts "Response status: #{response.status}"
    puts "Response body: #{response.body}"
    puts "Headers sent: #{response.request.headers.to_h.select { |k, _| k.start_with?('HTTP_') || ['CONTENT_TYPE', 'AUTHORIZATION'].include?(k) }}"
  end
  
  # Метод для преобразования JSON-ответа с пагинацией
  def json_data
    json['data'] || json
  end
  
  # Метод для анализа одной записи из ответа JSON
  def json_record(index = 0)
    if json['data']
      json['data'][index]
    else
      json[index]
    end
  end
end

# Подключаем хелпер к RSpec
RSpec.configure do |config|
  config.include ServicePointsTestHelper, type: :request
end
