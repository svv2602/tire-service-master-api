require 'swagger_helper'

RSpec.describe 'Users Management API', type: :request do
  path '/api/v1/users/me' do
    get('Получает информацию о текущем пользователе') do
      tags 'Users'
      description 'Возвращает информацию о текущем авторизованном пользователе'
      operationId 'getCurrentUser'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'Информация о пользователе') do
        schema type: :object,
               properties: {
                 data: {
                   '$ref': '#/components/schemas/User'
                 }
               }

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['id']).to eq(user.id)
          expect(data['data']['email']).to eq(user.email)
        end
      end

      response(401, 'Не авторизован') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:Authorization) { 'Bearer invalid_token' }

        run_test!
      end
    end
  end

  path '/api/v1/users' do
    get('Получает список всех пользователей') do
      tags 'Users'
      description 'Возвращает список всех пользователей системы (только для администраторов)'
      operationId 'getUsers'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :page, in: :query, type: :integer, required: false, description: 'Номер страницы'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Количество на странице'
      parameter name: :query, in: :query, type: :string, required: false, description: 'Поиск по email/имени'
      parameter name: :active, in: :query, type: :string, required: false, description: 'Фильтр по активности'

      response(200, 'Список пользователей') do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { '$ref': '#/components/schemas/User' }
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
        let(:user) { create(:user) } # Обычный пользователь
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        run_test!
      end
    end

    post('Создает нового пользователя') do
      tags 'Users'
      description 'Создает нового пользователя в системе (только для администраторов)'
      operationId 'createUser'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :user_params, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            '$ref': '#/components/schemas/UserCreateRequest'
          }
        },
        required: [:user]
      }

      response(201, 'Пользователь создан') do
        schema type: :object,
               properties: {
                 data: { '$ref': '#/components/schemas/User' },
                 message: { type: :string }
               }

        let(:admin_user) { create(:user, :admin) }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }
        let(:user_params) do
          {
            user: {
              email: 'new_user@example.com',
              first_name: 'Иван',
              last_name: 'Петров',
              password: 'password123',
              password_confirmation: 'password123',
              role_id: create(:role).id
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['email']).to eq('new_user@example.com')
          expect(data['message']).to be_present
        end
      end

      response(422, 'Ошибка валидации') do
        schema '$ref' => '#/components/schemas/ValidationErrorResponse'

        let(:admin_user) { create(:user, :admin) }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }
        let(:user_params) do
          {
            user: {
              email: 'invalid-email',
              first_name: '',
              password: '123'
            }
          }
        end

        run_test!
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        let(:user_params) { { user: { email: 'test@example.com' } } }

        run_test!
      end
    end
  end

  path '/api/v1/users/{id}' do
    parameter name: 'id', in: :path, type: :integer, description: 'ID пользователя'

    get('Получает информацию о пользователе') do
      tags 'Users'
      description 'Возвращает информацию о конкретном пользователе'
      operationId 'getUser'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'Информация о пользователе') do
        schema type: :object,
               properties: {
                 data: { '$ref': '#/components/schemas/User' }
               }

        let(:target_user) { create(:user) }
        let(:admin_user) { create(:user, :admin) }
        let(:id) { target_user.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['id']).to eq(target_user.id)
        end
      end

      response(404, 'Пользователь не найден') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:admin_user) { create(:user, :admin) }
        let(:id) { 99999 }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }

        run_test!
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:other_user) { create(:user) }
        let(:id) { other_user.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test!
      end
    end

    patch('Обновляет информацию о пользователе') do
      tags 'Users'
      description 'Обновляет информацию о пользователе'
      operationId 'updateUser'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :user_params, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            '$ref': '#/components/schemas/UserUpdateRequest'
          }
        },
        required: [:user]
      }

      response(200, 'Пользователь обновлен') do
        schema type: :object,
               properties: {
                 data: { '$ref': '#/components/schemas/User' },
                 message: { type: :string }
               }

        let(:target_user) { create(:user) }
        let(:admin_user) { create(:user, :admin) }
        let(:id) { target_user.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }
        let(:user_params) do
          {
            user: {
              first_name: 'Новое Имя',
              last_name: 'Новая Фамилия',
              phone: '+380501234567'
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['first_name']).to eq('Новое Имя')
        end
      end

      response(422, 'Ошибка валидации') do
        schema '$ref' => '#/components/schemas/ValidationErrorResponse'

        let(:target_user) { create(:user) }
        let(:admin_user) { create(:user, :admin) }
        let(:id) { target_user.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }
        let(:user_params) do
          {
            user: {
              email: 'invalid-email-format'
            }
          }
        end

        run_test!
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:other_user) { create(:user) }
        let(:id) { other_user.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        let(:user_params) { { user: { first_name: 'Test' } } }

        run_test!
      end
    end

    delete('Деактивирует пользователя') do
      tags 'Users'
      description 'Деактивирует пользователя в системе'
      operationId 'deactivateUser'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'Пользователь деактивирован') do
        schema type: :object,
               properties: {
                 message: { type: :string, example: 'Пользователь успешно деактивирован' }
               }

        let(:target_user) { create(:user) }
        let(:admin_user) { create(:user, :admin) }
        let(:id) { target_user.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['message']).to include('деактивирован')
        end
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:other_user) { create(:user) }
        let(:id) { other_user.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test!
      end
    end
  end
end 