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
              company_name: 'ООО "Шинный Центр"',
              contact_person: 'Иван Иванов',
              legal_address: 'ул. Шинная, 15',
              user_attributes: {
                email: 'contact@tire-center.com',
                password: 'password123',
                password_confirmation: 'password123',
                first_name: 'Иван',
                last_name: 'Иванов',
                phone: '+380501234567'
              }
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['company_name']).to eq('ООО "Шинный Центр"')
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
              company_name: '',
              user_attributes: {
                email: 'invalid-email'
              }
            }
          }
        end

        run_test!
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        let(:partner_params) { { partner: { company_name: 'Test' } } }

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

        let(:partner) { create(:partner, :with_new_user) }
        let(:admin_user) { create(:user, :admin) }
        let(:id) { partner.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['id']).to eq(partner.id)
          expect(data['data']['company_name']).to eq(partner.company_name)
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
        let(:partner) { create(:partner, :with_new_user) }
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

        let(:partner) { create(:partner, :with_new_user) }
        let(:admin_user) { create(:user, :admin) }
        let(:id) { partner.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }
        let(:partner_params) do
          {
            partner: {
              company_name: 'Updated Company Name',
              contact_person: 'Updated Contact Person',
              legal_address: 'Updated Address'
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['company_name']).to eq('Updated Company Name')
          expect(data['message']).to be_present
        end
      end

      response(422, 'Ошибка валидации') do
        schema '$ref' => '#/components/schemas/ValidationErrorResponse'

        let(:partner) { create(:partner, :with_new_user) }
        let(:admin_user) { create(:user, :admin) }
        let(:id) { partner.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }
        let(:partner_params) do
          {
            partner: {
              company_name: '',
              contact_person: ''
            }
          }
        end

        run_test!
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:partner) { create(:partner, :with_new_user) }
        let(:id) { partner.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        let(:partner_params) { { partner: { company_name: 'Test' } } }

        run_test!
      end
    end

    delete('Удаляет партнера') do
      tags 'Partners'
      description 'Деактивирует партнера в системе'
      operationId 'deletePartner'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'Партнер деактивирован') do
        schema type: :object,
               properties: {
                 message: { type: :string }
               }

        let(:partner) { create(:partner, :with_new_user) }
        let(:admin_user) { create(:user, :admin) }
        let(:id) { partner.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['message']).to be_present
        end
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:partner) { create(:partner, :with_new_user) }
        let(:id) { partner.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test!
      end
    end
  end
end 