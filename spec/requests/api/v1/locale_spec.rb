require 'swagger_helper'

RSpec.describe 'API V1 Locale', type: :request do
  path '/api/v1/locale' do
    get 'Get current locale' do
      tags 'Locale'
      produces 'application/json'

      response '200', 'locale found' do
        schema type: :object,
               properties: {
                 locale: { type: :string, example: 'uk' }
               },
               required: ['locale']

        run_test!
      end
    end

    put 'Update locale' do
      tags 'Locale'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]
      parameter name: :locale_params, in: :body, schema: {
        type: :object,
        properties: {
          locale: { type: :string, enum: ['uk', 'ru'], example: 'uk' }
        },
        required: ['locale']
      }

      response '200', 'locale updated' do
        schema type: :object,
               properties: {
                 locale: { type: :string, example: 'uk' },
                 message: { type: :string, example: 'Мову успішно змінено' }
               },
               required: ['locale', 'message']

        let(:locale_params) { { locale: 'uk' } }
        run_test!
      end

      response '200', 'locale updated for session' do
        schema type: :object,
               properties: {
                 locale: { type: :string, example: 'uk' },
                 message: { type: :string, example: 'Мову змінено для поточної сесії' }
               },
               required: ['locale', 'message']

        let(:locale_params) { { locale: 'uk' } }
        run_test!
      end

      response '422', 'invalid locale' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'Непідтримувана мова' }
               },
               required: ['error']

        let(:locale_params) { { locale: 'fr' } }
        run_test!
      end
    end
  end
end 