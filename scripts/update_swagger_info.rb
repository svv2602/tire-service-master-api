#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'

# Путь к файлу Swagger
swagger_file = 'swagger/v1/swagger.yaml'

# Читаем текущий файл
swagger_data = YAML.load_file(swagger_file)

# Обновляем информацию об API
swagger_data['info'] = {
  'title' => 'Tire Service API',
  'version' => 'v1',
  'description' => 'API для сервиса шиномонтажа. Предоставляет функциональность для управления клиентами, партнерами, сервисными точками, бронированиями и другими аспектами бизнеса.',
  'contact' => {
    'name' => 'API Support',
    'email' => 'support@tire-service.com'
  },
  'license' => {
    'name' => 'MIT',
    'url' => 'https://opensource.org/licenses/MIT'
  }
}

# Обновляем серверы
swagger_data['servers'] = [
  {
    'url' => 'http://localhost:8000',
    'description' => 'Development server'
  },
  {
    'url' => 'https://api.tire-service.com',
    'description' => 'Production server'
  }
]

# Добавляем компоненты безопасности
swagger_data['components'] ||= {}
swagger_data['components']['securitySchemes'] = {
  'bearerAuth' => {
    'type' => 'http',
    'scheme' => 'bearer',
    'bearerFormat' => 'JWT',
    'description' => 'JWT токен для аутентификации. Получается через эндпоинт /api/v1/auth/login'
  }
}

# Добавляем общие схемы
swagger_data['components']['schemas'] ||= {}
swagger_data['components']['schemas'].merge!({
  'Error' => {
    'type' => 'object',
    'properties' => {
      'error' => {
        'type' => 'string',
        'description' => 'Сообщение об ошибке'
      },
      'details' => {
        'type' => 'object',
        'description' => 'Дополнительные детали ошибки'
      }
    },
    'required' => ['error']
  },
  'ValidationError' => {
    'type' => 'object',
    'properties' => {
      'errors' => {
        'type' => 'object',
        'description' => 'Ошибки валидации по полям'
      }
    },
    'required' => ['errors']
  }
})

# Добавляем теги
swagger_data['tags'] = [
  {
    'name' => 'Authentication',
    'description' => 'Аутентификация и авторизация пользователей'
  },
  {
    'name' => 'Clients',
    'description' => 'Управление клиентами'
  },
  {
    'name' => 'Partners',
    'description' => 'Управление партнерами'
  },
  {
    'name' => 'Service Points',
    'description' => 'Управление сервисными точками'
  },
  {
    'name' => 'Bookings',
    'description' => 'Управление бронированиями'
  },
  {
    'name' => 'Photos',
    'description' => 'Управление фотографиями сервисных точек'
  },
  {
    'name' => 'Catalogs',
    'description' => 'Справочники и каталоги'
  },
  {
    'name' => 'System',
    'description' => 'Системные эндпоинты'
  }
]

# Записываем обновленный файл
File.write(swagger_file, swagger_data.to_yaml)

puts "✅ Swagger документация обновлена!"
puts "📄 Файл: #{swagger_file}"
puts "🔧 Обновлена информация об API, серверах, компонентах безопасности и тегах" 