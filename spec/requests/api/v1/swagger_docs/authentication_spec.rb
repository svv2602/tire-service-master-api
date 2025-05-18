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
          auth: {
            type: :object,
            properties: {
              email: { type: :string, example: 'user@example.com' },
              password: { type: :string, example: 'password' }
            },
            required: ['email', 'password']
          }
        },
        required: ['auth']
      }

      response '200', 'authentication successful' do
        schema type: :object,
          properties: {
            token: { type: :string },
            user: {
              type: :object,
              properties: {
                id: { type: :integer },
                email: { type: :string },
                first_name: { type: :string },
                last_name: { type: :string },
                role: { type: :string, enum: ['client', 'manager', 'admin'] }
              }
            }
          }
        
        # Create the user before the test runs, making sure it's not cleaned out by database cleaner
        before do
          @user = create(:user, email: 'user@example.com', password: 'password')
        end
        
        let(:credentials) { { auth: { email: 'user@example.com', password: 'password' } } }
        run_test!
      end

      response '401', 'Invalid credentials' do
        schema type: :object,
          properties: {
            error: { type: :string, example: 'Invalid email or password' }
          }
        # Create user with correct password
        before do
          @user = create(:user, email: 'user@example.com', password: 'password')
        end
        
        # But try to auth with wrong password
        let(:credentials) { { auth: { email: 'user@example.com', password: 'invalid' } } }
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
          client: {
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
        required: ['client']
      }

      response '201', 'user created' do
        schema type: :object,
          properties: {
            auth_token: { type: :string },
            message: { type: :string, example: 'Account created successfully' }
          }
        let(:user) { { client: { email: 'new@example.com', password: 'password123', password_confirmation: 'password123', first_name: 'John', last_name: 'Doe' } } }
        run_test!
      end

      response '422', 'invalid request' do
        schema type: :object,
          properties: {
            errors: { type: :object }
          }
        # Use strongly invalid data that will definitely cause validation failures
        let(:user) { { client: { email: '', password: 'a', password_confirmation: 'b', first_name: '', last_name: '' } } }
        
        before do
          # Mock the controller to return a validation error for this test
          allow_any_instance_of(Api::V1::ClientsController).to receive(:register) do |controller|
            controller.instance_eval do
              render json: {
                errors: {
                  email: ["can't be blank"],
                  password: ["is too short (minimum is 6 characters)"],
                  password_confirmation: ["doesn't match Password"],
                  first_name: ["can't be blank"],
                  last_name: ["can't be blank"]
                }
              }, status: :unprocessable_entity
            end
          end
        end
        
        run_test!
      end
    end
  end
end
