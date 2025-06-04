require 'swagger_helper'

RSpec.describe 'Partners API', type: :request do
  path '/api/v1/partners' do
    get('Получает список партнеров') do
      tags 'Partners'
      description 'Возвращает список всех партнеров с возможностью поиска и фильтрации'
      operationId 'getPartners'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :page, in: :query, type: :integer, required: false, description: 'Номер страницы'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Количество на странице'
      parameter name: :query, in: :query, type: :string, required: false, description: 'Поиск по названию или email'
      parameter name: :status, in: :query, type: :string, required: false, description: 'Фильтр по статусу'

      response(200, 'Список партнеров') do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { '$ref': '#/components/schemas/Partner' }
                 },
                 pagination: {
                   '$ref': '#/components/schemas/Pagination'
                 }
               }

        let(:admin_user) { create(:user, :admin) }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }
        let(:page) { 1 }
        let(:per_page) { 25 }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['pagination']).to include('current_page', 'total_pages')
        end
      end

      response(401, 'Не авторизован') do
        schema '$ref' => '#/components/schemas/ErrorResponse'
        let(:Authorization) { 'Bearer invalid_token' }
        run_test!
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'
        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        run_test!
      end
    end

    post('Создает нового партнера') do
      tags 'Partners'
      description 'Создает нового партнера в системе'
      operationId 'createPartner'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :partner_params, in: :body, schema: {
        type: :object,
        properties: {
          partner: {
            '$ref': '#/components/schemas/PartnerRequest'
          }
        },
        required: [:partner]
      }

      response(201, 'Партнер создан') do
        schema type: :object,
               properties: {
                 data: { '$ref': '#/components/schemas/Partner' },
                 message: { type: :string }
               }

        let(:admin_user) { create(:user, :admin) }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }
        let(:partner_params) do
          {
            partner: {
              name: 'ООО "Шинный Центр"',
              email: 'contact@tire-center.com',
              phone: '+380501234567',
              address: 'ул. Шинная, 15',
              description: 'Крупная сеть шиномонтажных мастерских',
              website: 'https://tire-center.com'
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['name']).to eq('ООО "Шинный Центр"')
          expect(data['message']).to be_present
        end
      end

      response(422, 'Ошибка валидации') do
        schema '$ref' => '#/components/schemas/ValidationErrorResponse'

        let(:admin_user) { create(:user, :admin) }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }
        let(:partner_params) do
          {
            partner: {
              name: '',
              email: 'invalid-email'
            }
          }
        end

        run_test!
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        let(:partner_params) { { partner: { name: 'Test' } } }

        run_test!
      end
    end
  end

  path '/api/v1/partners/{id}' do
    parameter name: 'id', in: :path, type: :integer, description: 'ID партнера'

    get('Получает информацию о партнере') do
      tags 'Partners'
      description 'Возвращает детальную информацию о партнере'
      operationId 'getPartner'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'Информация о партнере') do
        schema type: :object,
               properties: {
                 data: { '$ref': '#/components/schemas/PartnerDetailed' }
               }

        let(:partner) { create(:partner) }
        let(:admin_user) { create(:user, :admin) }
        let(:id) { partner.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['id']).to eq(partner.id)
          expect(data['data']['name']).to eq(partner.name)
        end
      end

      response(404, 'Партнер не найден') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:admin_user) { create(:user, :admin) }
        let(:id) { 99999 }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }

        run_test!
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:partner) { create(:partner) }
        let(:id) { partner.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test!
      end
    end

    patch('Обновляет информацию о партнере') do
      tags 'Partners'
      description 'Обновляет информацию о партнере'
      operationId 'updatePartner'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :partner_params, in: :body, schema: {
        type: :object,
        properties: {
          partner: {
            '$ref': '#/components/schemas/PartnerRequest'
          }
        },
        required: [:partner]
      }

      response(200, 'Партнер обновлен') do
        schema type: :object,
               properties: {
                 data: { '$ref': '#/components/schemas/Partner' },
                 message: { type: :string }
               }

        let(:partner) { create(:partner) }
        let(:admin_user) { create(:user, :admin) }
        let(:id) { partner.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }
        let(:partner_params) do
          {
            partner: {
              name: 'Обновленное название',
              phone: '+380509876543',
              website: 'https://new-website.com'
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['name']).to eq('Обновленное название')
        end
      end

      response(422, 'Ошибка валидации') do
        schema '$ref' => '#/components/schemas/ValidationErrorResponse'

        let(:partner) { create(:partner) }
        let(:admin_user) { create(:user, :admin) }
        let(:id) { partner.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }
        let(:partner_params) do
          {
            partner: {
              email: 'invalid-email-format'
            }
          }
        end

        run_test!
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:partner) { create(:partner) }
        let(:id) { partner.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        let(:partner_params) { { partner: { name: 'Test' } } }

        run_test!
      end
    end

    delete('Деактивирует партнера') do
      tags 'Partners'
      description 'Деактивирует партнера в системе'
      operationId 'deactivatePartner'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'Партнер деактивирован') do
        schema type: :object,
               properties: {
                 message: { type: :string, example: 'Партнер успешно деактивирован' }
               }

        let(:partner) { create(:partner) }
        let(:admin_user) { create(:user, :admin) }
        let(:id) { partner.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['message']).to include('деактивирован')
        end
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:partner) { create(:partner) }
        let(:id) { partner.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test!
      end
    end
  end
end 