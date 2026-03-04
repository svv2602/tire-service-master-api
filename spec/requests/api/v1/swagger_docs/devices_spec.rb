# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Devices API', type: :request do
  before(:all) do
    UserRole.find_or_create_by(name: 'client') do |role|
      role.description = 'End users booking tire services'
      role.is_active = true
    end
  end

  let(:user) { create(:client_user) }
  let(:Authorization) { "Bearer #{Auth::JsonWebToken.encode_access_token(user_id: user.id)}" }

  path '/api/v1/devices' do
    get 'Lists registered devices for current user' do
      tags 'Devices'
      produces 'application/json'
      security [bearerAuth: []]
      parameter name: :fields, in: :query, required: false, type: :string,
                description: 'Sparse fieldsets — comma-separated list of fields (e.g. fields=id,platform,device_name)'
      parameter name: 'API-Version', in: :header, required: false, type: :string,
                description: 'API version (default: 1)'

      response '200', 'devices listed' do
        schema type: :object,
          properties: {
            devices: { type: :array, items: { '$ref' => '#/components/schemas/Device' } },
            total_count: { type: :integer },
            active_count: { type: :integer }
          }

        before { create(:device, user: user) }

        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid' }
        run_test!
      end
    end

    post 'Registers a device token for push notifications' do
      tags 'Devices'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      description <<~DESC
        Register a mobile device token (APNs for iOS, FCM for Android) for push notifications.

        **Push Notification Registration Flow:**
        1. Mobile app obtains a device token from APNs (iOS) or FCM (Android)
        2. App sends POST /api/v1/devices with the token and platform info
        3. Server stores/updates the token linked to the authenticated user
        4. Server uses active device tokens to deliver push notifications
        5. On logout or uninstall, DELETE /api/v1/devices/:id deactivates the token

        If a device with the same token already exists, it is reassigned to the current user and reactivated.
      DESC

      parameter name: :device_data, in: :body, schema: { '$ref' => '#/components/schemas/DeviceRequest' }

      response '201', 'device registered' do
        schema type: :object,
          properties: {
            message: { type: :string },
            device: { '$ref' => '#/components/schemas/Device' }
          }

        let(:device_data) do
          {
            device: {
              device_token: "new_token_#{SecureRandom.hex(8)}",
              platform: 'ios',
              device_name: 'iPhone 15 Pro',
              device_model: 'iPhone15,2',
              os_version: '17.4',
              app_version: '1.0.0'
            }
          }
        end

        run_test!
      end

      response '200', 'existing device token updated' do
        let(:existing) { create(:device, user: user) }
        let(:device_data) do
          {
            device: {
              device_token: existing.device_token,
              platform: 'ios',
              app_version: '2.0.0'
            }
          }
        end

        run_test!
      end

      response '422', 'validation error' do
        let(:device_data) { { device: { device_token: '', platform: 'windows' } } }
        run_test!
      end
    end
  end

  path '/api/v1/devices/{id}' do
    parameter name: :id, in: :path, type: :integer

    get 'Shows device details' do
      tags 'Devices'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'device found' do
        schema '$ref' => '#/components/schemas/Device'

        let(:id) { create(:device, user: user).id }
        run_test!
      end

      response '404', 'device not found' do
        let(:id) { 999_999 }
        run_test!
      end
    end

    patch 'Updates device info' do
      tags 'Devices'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :device_data, in: :body, schema: {
        type: :object,
        properties: {
          device: {
            type: :object,
            properties: {
              device_name: { type: :string },
              device_model: { type: :string },
              os_version: { type: :string },
              app_version: { type: :string }
            }
          }
        }
      }

      response '200', 'device updated' do
        let(:id) { create(:device, user: user).id }
        let(:device_data) { { device: { app_version: '2.0.0' } } }
        run_test!
      end
    end

    delete 'Deactivates a device' do
      tags 'Devices'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'device deactivated' do
        let(:id) { create(:device, user: user).id }
        run_test!
      end
    end
  end
end
