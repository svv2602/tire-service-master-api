# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root.join('swagger').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under openapi_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a openapi_spec tag to the
  # the root example_group in your specs, e.g. describe '...', openapi_spec: 'v2/swagger.json'
  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'Tire Service API',
        version: 'v1',
        description: 'API для сервиса шиномонтажа. Предоставляет функциональность для управления клиентами, партнерами, сервисными точками, бронированиями и другими аспектами бизнеса.',
        contact: {
          name: 'API Support',
          email: 'support@tire-service.com'
        },
        license: {
          name: 'MIT',
          url: 'https://opensource.org/licenses/MIT'
        }
      },
      paths: {},
      servers: [
        {
          url: 'http://localhost:8000',
          description: 'Development server'
        },
        {
          url: 'https://api.tire-service.com',
          description: 'Production server'
        }
      ],
      components: {
        securitySchemes: {
          bearerAuth: {
            type: 'http',
            scheme: 'bearer',
            bearerFormat: 'JWT',
            description: 'JWT токен для аутентификации. Получается через эндпоинт /api/v1/auth/login'
          }
        },
        schemas: {
          Error: {
            type: 'object',
            properties: {
              error: {
                type: 'string',
                description: 'Сообщение об ошибке'
              },
              details: {
                type: 'object',
                description: 'Дополнительные детали ошибки'
              }
            },
            required: ['error']
          },
          ValidationError: {
            type: 'object',
            properties: {
              errors: {
                type: 'object',
                description: 'Ошибки валидации по полям'
              }
            },
            required: ['errors']
          }
        }
      },
      tags: [
        {
          name: 'Authentication',
          description: 'Аутентификация и авторизация пользователей'
        },
        {
          name: 'Clients',
          description: 'Управление клиентами'
        },
        {
          name: 'Partners',
          description: 'Управление партнерами'
        },
        {
          name: 'Service Points',
          description: 'Управление сервисными точками'
        },
        {
          name: 'Bookings',
          description: 'Управление бронированиями'
        },
        {
          name: 'Photos',
          description: 'Управление фотографиями сервисных точек'
        },
        {
          name: 'Catalogs',
          description: 'Справочники и каталоги'
        },
        {
          name: 'System',
          description: 'Системные эндпоинты'
        }
      ]
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :yaml
end 