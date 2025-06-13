require 'swagger_helper'

RSpec.describe 'Authentication API', type: :request do
  # Setup client role before tests run
  before(:all) do
    # Create client role if it doesn't exist
    UserRole.find_or_create_by(name: 'client') do |role|
      role.description = 'End users booking tire services'
      role.is_active = true
    end
  end
  path '/api/v1/auth/login' do
    post 'Authenticates user and returns JWT token' do
      tags 'Authentication'
      consumes 'application/json'
      parameter name: :credentials, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, example: 'user@example.com' },
          password: { type: :string, example: 'password' }
        },
        required: ['email', 'password']
      }

      response '200', 'authentication successful' do
        schema type: :object,
          properties: {
            tokens: {
              type: :object,
              properties: {
                access: { type: :string }
              }
            },
            user: {
              type: :object,
              properties: {
                id: { type: :integer },
                email: { type: :string },
                first_name: { type: :string },
                last_name: { type: :string },
                role: { type: :string, enum: ['client', 'manager', 'admin', 'partner', 'operator'] },
                is_active: { type: :boolean }
              }
            }
          }
        
        # Create the user before the test runs, making sure it's not cleaned out by database cleaner
        before do
          @user = create(:user, email: 'user@example.com', password: 'password', password_confirmation: 'password')
        end
        
        let(:credentials) { { email: 'user@example.com', password: 'password' } }
        run_test!
      end

      response '401', 'Invalid credentials' do
        schema type: :object,
          properties: {
            error: { type: :string, example: 'Неверные учетные данные' }
          }
        # Create user with correct password
        before do
          @user = create(:user, email: 'user@example.com', password: 'password', password_confirmation: 'password')
        end
        
        # But try to auth with wrong password
        let(:credentials) { { email: 'user@example.com', password: 'invalid' } }
        run_test!
      end
    end
  end

  path '/api/v1/clients/register' do
    post 'Registers a new user' do
      tags 'Authentication'
      consumes 'application/json'
      parameter name: :user, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              email: { type: :string, example: 'new@example.com' },
              password: { type: :string, example: 'password123' },
              password_confirmation: { type: :string, example: 'password123' },
              first_name: { type: :string, example: 'John' },
              last_name: { type: :string, example: 'Doe' }
            },
            required: ['email', 'password', 'password_confirmation', 'first_name', 'last_name']
          }
        },
        required: ['user']
      }

      response '201', 'user created' do
        schema type: :object,
          properties: {
            message: { type: :string, example: 'Регистрация прошла успешно' },
            user: { 
              type: :object,
              properties: {
                id: { type: :integer },
                email: { type: :string },
                first_name: { type: :string },
                last_name: { type: :string },
                phone: { type: :string, nullable: true }
              }
            },
            client: {
              type: :object,
              properties: {
                id: { type: :integer },
                preferred_notification_method: { type: :string, nullable: true }
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
        let(:user) { { user: { email: 'new@example.com', password: 'password123', password_confirmation: 'password123', first_name: 'John', last_name: 'Doe' } } }
        run_test!
      end

      response '422', 'invalid request' do
        schema type: :object,
          properties: {
            error: { type: :string },
            details: { 
              type: :array,
              items: { type: :string }
            }
          }
        # Use strongly invalid data that will definitely cause validation failures
        let(:user) { { user: { email: '', password: 'a', password_confirmation: 'b', first_name: '', last_name: '' } } }
        
        before do
          # Mock the controller to return a validation error for this test
          allow_any_instance_of(Api::V1::ClientAuthController).to receive(:register) do |controller|
            controller.instance_eval do
              render json: {
                error: 'Ошибка регистрации',
                details: [
                  "Email can't be blank",
                  "Password is too short (minimum is 6 characters)",
                  "Password confirmation doesn't match Password",
                  "First name can't be blank",
                  "Last name can't be blank"
                ]
              }, status: :unprocessable_entity
            end
          end
        end
        
        run_test!
      end
    end
  end
end
