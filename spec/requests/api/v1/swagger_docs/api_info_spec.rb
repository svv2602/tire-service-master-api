require 'swagger_helper'

RSpec.describe 'API Information', type: :request do
  path '/api/v1/health' do
    get 'Health check endpoint' do
      tags 'System'
      description 'Проверка состояния API'
      
      response '200', 'API работает' do
        schema type: :object,
               properties: {
                 status: { type: :string, example: 'ok' },
                 timestamp: { type: :string, format: 'date-time' },
                 version: { type: :string, example: 'v1' }
               }
        
        run_test!
      end
    end
  end
end 