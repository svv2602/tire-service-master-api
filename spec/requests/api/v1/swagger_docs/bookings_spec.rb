require 'swagger_helper'

RSpec.describe 'Bookings API', type: :request, swagger: true do
  before(:all) do
    # Create user roles
    @client_role = UserRole.find_by(name: 'client') || create(:user_role, name: 'client', description: 'Client role')
    @partner_role = UserRole.find_by(name: 'partner') || create(:user_role, name: 'partner', description: 'Partner role')
    @admin_role = UserRole.find_by(name: 'admin') || create(:user_role, name: 'admin', description: 'Admin role')
    
    # Create all necessary booking statuses
    BookingTestHelper.ensure_all_booking_statuses_exist
  end
  
  let(:client_user) { create(:user, role_id: @client_role.id) }
  let(:partner_user) { create(:user, role_id: @partner_role.id) }
  let(:admin_user) { create(:user, role_id: @admin_role.id) }
  
  let(:client) { create(:client, user: client_user) }
  let(:partner) { create(:partner, user: partner_user) }
  
  let(:client_auth_token) { Auth::JsonWebToken.encode(user_id: client_user.id) }
  let(:partner_auth_token) { Auth::JsonWebToken.encode(user_id: partner_user.id) }
  let(:admin_auth_token) { Auth::JsonWebToken.encode(user_id: admin_user.id) }
  
  let(:Authorization) { "Bearer #{client_auth_token}" }
  let(:partner_Authorization) { "Bearer #{partner_auth_token}" }
  let(:admin_Authorization) { "Bearer #{admin_auth_token}" }
  
  let(:region) { create(:region) }
  let(:city) { create(:city, region: region) }
  let(:service_point) { create(:service_point, partner: partner, city: city) }
  let(:service) { create(:service) }
  let(:car_type) { create(:car_type) }
  let(:slot) { create(:schedule_slot, service_point: service_point) }
  
  # Create bookings with various statuses using our helper
  let(:booking) { create_booking_with_status('pending', client: client, service_point: service_point, car_type: car_type, slot: slot) }
  let(:pending_booking) { create_booking_with_status('pending', client: client, service_point: service_point, car_type: car_type) }
  let(:confirmed_booking) { create_booking_with_status('confirmed', client: client, service_point: service_point, car_type: car_type) }
  let(:booking_id) { booking.id }
  let(:client_id) { client.id }

  path '/api/v1/clients/{client_id}/bookings' do
    get 'Получает все бронирования для текущего пользователя' do
      tags 'Bookings'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :client_id, in: :path, type: :integer, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Номер страницы'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Элементов на странице'
      parameter name: :date, in: :query, type: :string, required: false, description: 'Фильтр по дате (формат YYYY-MM-DD)'
      parameter name: :from_date, in: :query, type: :string, required: false, description: 'Начальная дата для фильтра по периоду'
      parameter name: :to_date, in: :query, type: :string, required: false, description: 'Конечная дата для фильтра по периоду'
      parameter name: :status_id, in: :query, type: :integer, required: false, description: 'Фильтр по ID статуса бронирования'
      parameter name: :filter, in: :query, type: :string, required: false, description: 'Предопределенный фильтр (upcoming, past, today)'

      response '200', 'bookings found' do
        schema type: :array,
          items: {
            type: :object,
            properties: {
              id: { type: :integer },
              booking_date: { type: :string, format: :date },
              start_time: { type: :string },
              end_time: { type: :string },
              status: { 
                type: :object,
                properties: {
                  id: { 
                    oneOf: [
                      { type: :integer },
                      { type: :null }
                    ]
                  },
                  name: { type: :string }
                }
              },
              total_price: { 
                oneOf: [
                  { type: :number },
                  { type: :string, pattern: '^\d+(\.\d+)?$' },
                  { type: :null }
                ]
              },
              car_type: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  name: { type: :string },
                  description: { type: :string }
                }
              }
            }
          }
        
        let(:Authorization) { admin_Authorization }
        let(:'Content-Type') { 'application/json' }
        let(:client_id) { client.id }
        let(:test) { 'true' }
        run_test!
      end

      response '401', 'Unauthorized' do
        schema type: :object,
          properties: {
            message: { type: :string, example: 'Unauthorized' }
          }
        let(:Authorization) { "Bearer invalid" }
        run_test!
      end
    end
    
    post 'Creates a new booking' do
      tags 'Bookings'
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :client_id, in: :path, type: :integer, required: true
      parameter name: :booking, in: :body, schema: {
        type: :object,
        properties: {
          booking: {
            type: :object,
            properties: {
              service_point_id: { type: :integer },
              booking_date: { type: :string, format: :date },
              start_time: { type: :string, format: :time },
              end_time: { type: :string, format: :time },
              car_type_id: { type: :integer },
              slot_id: { type: :integer },
              services: { 
                type: :array,
                items: { 
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    quantity: { type: :integer }
                  }
                }
              }
            },
            required: ['service_point_id', 'booking_date', 'services', 'car_type_id', 'slot_id']
          }
        }
      }

      response '201', 'booking created' do
        schema type: :object,
          properties: {
            id: { type: :integer },
            client_id: { type: :integer },
            service_point_id: { type: :integer },
            booking_date: { type: :string, format: :date },
            start_time: { type: :string },
            end_time: { type: :string },
            status: { 
              type: :object, 
              properties: {
                id: { 
                  oneOf: [
                    { type: :integer },
                    { type: :null }
                  ]
                },
                name: { type: :string }
              }
            },
            total_price: { 
              oneOf: [
                { type: :number },
                { type: :string, pattern: '^\d+(\.\d+)?$' },
                { type: :null }
              ]
            },
            car_type: {
              type: :object,
              properties: {
                id: { type: :integer },
                name: { type: :string },
                description: { type: :string }
              }
            }
          }
        
        let(:booking) do 
          { 
            booking: { 
              service_point_id: service_point.id, 
              booking_date: 1.day.from_now.to_date.to_s, 
              start_time: "10:00", 
              end_time: "11:00",
              car_type_id: car_type.id,
              slot_id: slot.id,
              status_id: BookingStatus.find_by(name: 'pending').id,
              payment_status_id: PaymentStatus.find_by(name: 'pending').id,
              services: [{ id: service.id, quantity: 1 }] 
            } 
          }
        end
        
        run_test!
      end

      response '422', 'invalid request' do
        schema type: :object,
          properties: {
            errors: { type: :object }
          }
        let(:booking) { { booking: { service_point_id: nil } } }
        run_test!
      end
    end
  end

  path '/api/v1/clients/{client_id}/bookings/{id}' do
    get 'Retrieves a booking' do
      tags 'Bookings'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :client_id, in: :path, type: :integer, required: true
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'booking found' do
        schema type: :object,
          properties: {
            id: { type: :integer },
            booking_date: { type: :string, format: :date },
            start_time: { type: :string },
            end_time: { type: :string },
            client_id: { type: :integer },
            service_point_id: { type: :integer },
            total_price: { 
              oneOf: [
                { type: :number },
                { type: :string, pattern: '^\d+(\.\d+)?$' },
                { type: :null }
              ]
            },
            status: { 
              type: :object,
              properties: {
                id: { 
                  oneOf: [
                    { type: :integer },
                    { type: :null }
                  ]
                },
                name: { type: :string }
              }
            },
            car_type: {
              type: :object,
              properties: {
                id: { type: :integer },
                name: { type: :string },
                description: { type: :string }
              }
            }
          }
        let(:id) { booking.id }
        run_test!
      end

      response '404', 'booking not found' do
        let(:id) { 999 }
        run_test!
      end
    end
    
    put 'Updates a booking' do
      tags 'Bookings'
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :client_id, in: :path, type: :integer, required: true
      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :booking_param, in: :body, schema: {
        type: :object,
        properties: {
          booking: {
            type: :object,
            properties: {
              booking_date: { type: :string, format: :date },
              start_time: { type: :string, format: :time },
              end_time: { type: :string, format: :time },
              car_id: { type: :integer },
              car_type_id: { type: :integer },
              notes: { type: :string }
            }
          }
        }
      }
      
      response '422', 'booking validation errors' do
        schema type: :object,
          properties: {
            errors: { 
              type: :object,
              properties: {
                booking_date: { 
                  type: :array,
                  items: { type: :string }
                }
              }
            }
          }
        # Use a valid booking ID that exists
        let(:id) { create_booking_with_status('pending', client: client, service_point: service_point).id }
        let(:booking_param) { { booking: { booking_date: nil } } }
        run_test!
      end
      
      response '404', 'booking not found' do
        let(:id) { 'invalid' }
        let(:booking_param) { { booking: { notes: 'Updated notes' } } }
        run_test!
      end
    end
    
    delete 'Cancels a booking' do
      tags 'Bookings'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :client_id, in: :path, type: :integer, required: true
      parameter name: :id, in: :path, type: :integer, required: true
      
      response '200', 'booking canceled' do
        schema type: :object,
          properties: {
            id: { type: :integer },
            status: { 
              type: :object, 
              properties: {
                id: { 
                  oneOf: [
                    { type: :integer },
                    { type: :null }
                  ]
                },
                name: { type: :string, example: 'canceled_by_client' }
              }
            }
          }
        let(:id) { create_booking_with_status('pending', client: client, service_point: service_point).id }
        run_test!
      end
      
      response '404', 'booking not found' do
        let(:id) { 'invalid' }
        run_test!
      end
    end
  end
  
  path '/api/v1/bookings/{id}/confirm' do
    post 'Confirms a booking' do
      tags 'Bookings'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :integer, required: true
      
      response '200', 'booking confirmed' do
        schema type: :object,
          properties: {
            id: { type: :integer },
            status: { 
              type: :object, 
              properties: {
                id: { type: :integer },
                name: { type: :string, example: 'confirmed' }
              }
            }
          }
        let(:Authorization) { partner_Authorization }
        let(:id) { pending_booking.id }
        run_test!
      end
      
      response '401', 'unauthorized' do
        let(:Authorization) { "Bearer invalid" }
        let(:id) { pending_booking.id }
        run_test!
      end
    end
  end
  
  # Helper method to create or find a valid cancellation reason
  let(:valid_reason) do
    CancellationReason.find_or_create_by(
      name: 'client_canceled',
      description: 'Client canceled booking'
    )
  end
  
  path '/api/v1/bookings/{id}/cancel' do
    post 'Cancels a booking' do
      tags 'Bookings'
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :cancellation_params, in: :body, schema: {
        type: :object,
        properties: {
          booking: {
            type: :object,
            properties: {
              cancellation_reason_id: { type: :integer },
              cancellation_comment: { type: :string }
            }
          }
        }
      }
      
      # Create a booking for cancellation or use an existing one
      let(:booking_for_cancel) do
        if ENV['SWAGGER_DRY_RUN']
          # For Swagger tests, just use any booking ID
          { id: 1 }
        else
          create_booking_with_status('confirmed')
        end
      end
      
      response '200', 'booking canceled' do
        schema type: :object,
          properties: {
            id: { type: :integer },
            status: { 
              type: :object, 
              properties: {
                id: { 
                  oneOf: [
                    { type: :integer },
                    { type: :null }
                  ]
                },
                name: { type: :string, example: 'canceled_by_client' }
              }
            }
          }

        let(:id) { booking_for_cancel[:id] || booking_for_cancel.id }
        let(:cancellation_params) { { booking: { cancellation_reason_id: valid_reason.id } } }
        let(:Authorization) { partner_Authorization }
        let(:'Content-Type') { 'application/json' }
        run_test!
      end
      
      response '401', 'unauthorized' do
        let(:Authorization) { "Bearer invalid" }
        let(:id) { booking_for_cancel[:id] || booking_for_cancel.id }
        let(:cancellation_params) { { booking: { cancellation_reason_id: valid_reason.id } } }
        run_test!
      end
    end
  end
end
