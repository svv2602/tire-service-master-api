require 'swagger_helper'

RSpec.describe 'api/v1/client_auth', type: :request do
  before do
    # Создаем роль клиента если её нет
    @client_role = UserRole.find_or_create_by(name: 'client') do |role|
      role.description = 'Клиент сервиса'
    end
  end

  path '/api/v1/clients/register' do
    post('Регистрация нового клиента') do
      tags 'Клиентская авторизация'
      description 'Регистрация нового клиента в системе'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :user_data, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              first_name: { type: :string, example: 'Иван' },
              last_name: { type: :string, example: 'Иванов' },
              email: { type: :string, example: 'ivan@example.com' },
              phone: { type: :string, example: '+380123456789' },
              password: { type: :string, example: 'password123' },
              password_confirmation: { type: :string, example: 'password123' }
            },
            required: ['first_name', 'last_name', 'email', 'password']
          }
        },
        required: ['user']
      }

      response(201, 'Успешная регистрация') do
        schema type: :object,
               properties: {
                 message: { type: :string },
                 user: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     email: { type: :string },
                     first_name: { type: :string },
                     last_name: { type: :string },
                     phone: { type: :string }
                   }
                 },
                 client: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     preferred_notification_method: { type: :string }
                   }
                 },
                 tokens: {
                   type: :object,
                   properties: {
                     access: { type: :string },
                     refresh: { type: :string }
                   }
                 }
               }

        let(:user_data) do
          {
            user: {
              first_name: 'Иван',
              last_name: 'Иванов',
              email: 'ivan@example.com',
              phone: '+380123456789',
              password: 'password123',
              password_confirmation: 'password123'
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['message']).to eq('Регистрация прошла успешно')
          expect(data['user']['email']).to eq('ivan@example.com')
          expect(data['tokens']['access']).to be_present
          expect(data['tokens']['refresh']).to be_present
        end
      end

      response(422, 'Ошибка валидации') do
        schema type: :object,
               properties: {
                 error: { type: :string },
                 details: { type: :array, items: { type: :string } }
               }

        let(:user_data) do
          {
            user: {
              first_name: '',
              last_name: 'Иванов',
              email: 'invalid-email',
              password: '123'
            }
          }
        end

        run_test!
      end
    end
  end

  path '/api/v1/clients/login' do
    post('Вход клиента в систему') do
      tags 'Клиентская авторизация'
      description 'Авторизация существующего клиента по email или телефону'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :auth_data, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, example: 'ivan@example.com', description: 'Email клиента' },
          password: { type: :string, example: 'password123' }
        },
        required: ['email', 'password']
      }

      response(200, 'Успешный вход') do
        schema type: :object,
               properties: {
                 user: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     email: { type: :string },
                     first_name: { type: :string },
                     last_name: { type: :string },
                     is_active: { type: :boolean },
                     role: { type: :string }
                   }
                 },
                 tokens: {
                   type: :object,
                   properties: {
                     access: { type: :string }
                   }
                 }
               }

        let!(:user) do
          User.create!(
            first_name: 'Иван',
            last_name: 'Иванов',
            email: 'ivan@example.com',
            phone: '+380123456789',
            password: 'password123',
            password_confirmation: 'password123',
            role: @client_role
          )
        end

        let(:auth_data) do
          {
            email: 'ivan@example.com',
            password: 'password123'
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['user']['email']).to eq('ivan@example.com')
          expect(data['tokens']['access']).to be_present
        end
      end

      response(404, 'Пользователь не найден') do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        let(:auth_data) do
          {
            email: 'nonexistent@example.com',
            password: 'password123'
          }
        end

        run_test!
      end
    end
  end

  path '/api/v1/clients/me' do
    get('Информация о клиенте') do
      tags 'Клиентская авторизация'
      description 'Получение информации о текущем авторизованном клиенте'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'Информация о клиенте') do
        schema type: :object,
               properties: {
                 user: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     email: { type: :string },
                     first_name: { type: :string },
                     last_name: { type: :string },
                     phone: { type: :string },
                     role: { type: :string }
                   }
                 },
                 client: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     preferred_notification_method: { type: :string },
                     total_bookings: { type: :integer },
                     completed_bookings: { type: :integer },
                     average_rating_given: { type: :number }
                   }
                 }
               }

        let!(:user) do
          user = User.create!(
            first_name: 'Иван',
            last_name: 'Иванов',
            email: 'ivan@example.com',
            phone: '+380123456789',
            password: 'password123',
            password_confirmation: 'password123',
            role: @client_role
          )
          
          # Создаем клиента для пользователя
          Client.create!(
            user: user,
            preferred_notification_method: 'email'
          )
          
          user
        end
        
        let(:Authorization) { "Bearer #{Auth::JsonWebToken.encode_access_token(user_id: user.id)}" }

        run_test!
      end

      response(403, 'Доступ запрещен') do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        let!(:admin_role) do
          UserRole.find_or_create_by(name: 'admin') do |role|
            role.description = 'Администратор системы'
          end
        end
        
        let!(:admin) do
          User.create!(
            first_name: 'Admin',
            last_name: 'User',
            email: 'admin@example.com',
            password: 'admin123',
            password_confirmation: 'admin123',
            role: admin_role
          )
        end
        
        let(:Authorization) { "Bearer #{Auth::JsonWebToken.encode_access_token(user_id: admin.id)}" }

        run_test!
      end
    end
  end

  path '/api/v1/clients/logout' do
    post('Успешный выход') do
      tags 'Клиентская авторизация'
      description 'Выход клиента из системы'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'Успешный выход') do
        schema type: :object,
               properties: {
                 message: { type: :string }
               }

        let!(:user) do
          User.create!(
            first_name: 'Иван',
            last_name: 'Иванов',
            email: 'ivan@example.com',
            phone: '+380123456789',
            password: 'password123',
            password_confirmation: 'password123',
            role: @client_role
          )
        end
        
        let(:Authorization) { "Bearer #{Auth::JsonWebToken.encode_access_token(user_id: user.id)}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['message']).to eq('Выход выполнен успешно')
        end
      end
    end
  end
end 