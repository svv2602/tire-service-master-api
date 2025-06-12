require 'swagger_helper'

RSpec.describe 'Reviews API', type: :request do
  path '/api/v1/clients/{client_id}/reviews' do
    parameter name: :client_id, in: :path, type: :integer, required: true, description: 'ID клиента'

    post('Создает новый отзыв') do
      tags 'Reviews'
      description 'Создает новый отзыв для завершенного бронирования'
      operationId 'createReview'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :review_params, in: :body, schema: {
        type: :object,
        properties: {
          review: {
            type: :object,
            properties: {
              booking_id: { type: :integer },
              rating: { type: :integer },
              comment: { type: :string },
              recommend: { type: :boolean }
            },
            required: [:booking_id, :rating]
          }
        },
        required: [:review]
      }

      response(201, 'Отзыв создан') do
        let(:user) { create(:user) }
        let(:client) { create(:client, user: user) }
        let(:service_point) { create(:service_point) }
        let(:booking) do
          create_booking_with_status('completed',
            client: client,
            service_point: service_point
          )
        end
        let(:client_id) { client.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        let(:review_params) do
          {
            review: {
              booking_id: booking.id,
              rating: 5,
              comment: 'Отличный сервис! Быстро и качественно выполнили шиномонтаж.',
              recommend: true
            }
          }
        end

        run_test!
      end

      response(422, 'Ошибка валидации') do
        let(:user) { create(:user) }
        let(:client) { create(:client, user: user) }
        let(:service_point) { create(:service_point) }
        let(:booking) do
          create_booking_with_status('pending',
            client: client,
            service_point: service_point
          )
        end
        let(:client_id) { client.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        let(:review_params) do
          {
            review: {
              booking_id: booking.id,
              rating: 6,
              comment: ''
            }
          }
        end

        run_test!
      end

      response(403, 'Недостаточно прав доступа') do
        let(:user) { create(:user) }
        let(:other_user) { create(:user) }
        let(:other_client) { create(:client, user: other_user) }
        let(:service_point) { create(:service_point) }
        let(:booking) do
          create_booking_with_status('completed',
            client: other_client,
            service_point: service_point
          )
        end
        let(:client_id) { other_client.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        let(:review_params) do
          {
            review: {
              booking_id: booking.id,
              rating: 5,
              comment: 'Test'
            }
          }
        end

        run_test!
      end

      response(401, 'Не авторизован') do
        let(:client) { create(:client) }
        let(:service_point) { create(:service_point) }
        let(:booking) do
          create_booking_with_status('completed',
            client: client,
            service_point: service_point
          )
        end
        let(:client_id) { client.id }
        let(:Authorization) { 'Bearer invalid_token' }
        let(:review_params) do
          {
            review: {
              booking_id: booking.id,
              rating: 5,
              comment: 'Test'
            }
          }
        end

        run_test!
      end
    end
  end

  path '/api/v1/clients/{client_id}/reviews/{id}' do
    parameter name: :client_id, in: :path, type: :integer, required: true, description: 'ID клиента'
    parameter name: :id, in: :path, type: :integer, required: true, description: 'ID отзыва'

    get('Получает информацию об отзыве') do
      tags 'Reviews'
      description 'Возвращает детальную информацию об отзыве'
      operationId 'getReview'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'Информация об отзыве') do
        let(:user) { create(:user) }
        let(:client) { create(:client, user: user) }
        let(:service_point) { create(:service_point) }
        let(:booking) do
          create_booking_with_status('completed',
            client: client,
            service_point: service_point
          )
        end
        let(:review) do
          create(:review,
            client: client,
            booking: booking,
            service_point: service_point,
            rating: 5,
            comment: 'Great service!'
          )
        end
        let(:client_id) { client.id }
        let(:id) { review.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test!
      end

      response(404, 'Отзыв не найден') do
        let(:user) { create(:user) }
        let(:client) { create(:client, user: user) }
        let(:client_id) { client.id }
        let(:id) { 0 }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test!
      end
    end

    patch('Обновляет отзыв') do
      tags 'Reviews'
      description 'Обновляет существующий отзыв'
      operationId 'updateReview'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :review_params, in: :body, schema: {
        type: :object,
        properties: {
          review: {
            type: :object,
            properties: {
              rating: { type: :integer },
              comment: { type: :string },
              recommend: { type: :boolean }
            }
          }
        },
        required: [:review]
      }

      response(200, 'Отзыв обновлен') do
        let(:user) { create(:user) }
        let(:client) { create(:client, user: user) }
        let(:service_point) { create(:service_point) }
        let(:booking) do
          create_booking_with_status('completed',
            client: client,
            service_point: service_point
          )
        end
        let(:review) do
          create(:review,
            client: client,
            booking: booking,
            service_point: service_point,
            rating: 5,
            comment: 'Great service!'
          )
        end
        let(:client_id) { client.id }
        let(:id) { review.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        let(:review_params) do
          {
            review: {
              rating: 4,
              comment: 'Good service, but could be better'
            }
          }
        end

        run_test!
      end

      response(422, 'Ошибка валидации') do
        let(:user) { create(:user) }
        let(:client) { create(:client, user: user) }
        let(:service_point) { create(:service_point) }
        let(:booking) do
          create_booking_with_status('completed',
            client: client,
            service_point: service_point
          )
        end
        let(:review) do
          create(:review,
            client: client,
            booking: booking,
            service_point: service_point,
            rating: 5,
            comment: 'Great service!'
          )
        end
        let(:client_id) { client.id }
        let(:id) { review.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        let(:review_params) do
          {
            review: {
              rating: 6,
              comment: ''
            }
          }
        end

        run_test!
      end

      response(403, 'Недостаточно прав доступа') do
        let(:user) { create(:user) }
        let(:other_user) { create(:user) }
        let(:other_client) { create(:client, user: other_user) }
        let(:service_point) { create(:service_point) }
        let(:booking) do
          create_booking_with_status('completed',
            client: other_client,
            service_point: service_point
          )
        end
        let(:review) do
          create(:review,
            client: other_client,
            booking: booking,
            service_point: service_point,
            rating: 5,
            comment: 'Great service!'
          )
        end
        let(:client_id) { other_client.id }
        let(:id) { review.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        let(:review_params) do
          {
            review: {
              rating: 4,
              comment: 'Not so great'
            }
          }
        end

        run_test!
      end

      response(401, 'Не авторизован') do
        let(:client) { create(:client) }
        let(:service_point) { create(:service_point) }
        let(:booking) do
          create_booking_with_status('completed',
            client: client,
            service_point: service_point
          )
        end
        let(:review) do
          create(:review,
            client: client,
            booking: booking,
            service_point: service_point,
            rating: 5,
            comment: 'Great service!'
          )
        end
        let(:client_id) { client.id }
        let(:id) { review.id }
        let(:Authorization) { 'Bearer invalid_token' }
        let(:review_params) do
          {
            review: {
              rating: 4,
              comment: 'Not so great'
            }
          }
        end

        run_test!
      end
    end

    delete('Удаляет отзыв') do
      tags 'Reviews'
      description 'Удаляет существующий отзыв'
      operationId 'deleteReview'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'Отзыв удален') do
        let(:user) { create(:user) }
        let(:client) { create(:client, user: user) }
        let(:service_point) { create(:service_point) }
        let(:booking) do
          create_booking_with_status('completed',
            client: client,
            service_point: service_point
          )
        end
        let(:review) do
          create(:review,
            client: client,
            booking: booking,
            service_point: service_point,
            rating: 5,
            comment: 'Great service!'
          )
        end
        let(:client_id) { client.id }
        let(:id) { review.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test!
      end

      response(403, 'Недостаточно прав доступа') do
        let(:user) { create(:user) }
        let(:other_user) { create(:user) }
        let(:other_client) { create(:client, user: other_user) }
        let(:service_point) { create(:service_point) }
        let(:booking) do
          create_booking_with_status('completed',
            client: other_client,
            service_point: service_point
          )
        end
        let(:review) do
          create(:review,
            client: other_client,
            booking: booking,
            service_point: service_point,
            rating: 5,
            comment: 'Great service!'
          )
        end
        let(:client_id) { other_client.id }
        let(:id) { review.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test!
      end

      response(404, 'Отзыв не найден') do
        let(:user) { create(:user) }
        let(:client) { create(:client, user: user) }
        let(:client_id) { client.id }
        let(:id) { 0 }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test!
      end

      response(401, 'Не авторизован') do
        let(:client) { create(:client) }
        let(:service_point) { create(:service_point) }
        let(:booking) do
          create_booking_with_status('completed',
            client: client,
            service_point: service_point
          )
        end
        let(:review) do
          create(:review,
            client: client,
            booking: booking,
            service_point: service_point,
            rating: 5,
            comment: 'Great service!'
          )
        end
        let(:client_id) { client.id }
        let(:id) { review.id }
        let(:Authorization) { 'Bearer invalid_token' }

        run_test!
      end
    end
  end

  path '/api/v1/service_points/{service_point_id}/reviews' do
    parameter name: :service_point_id, in: :path, type: :integer, required: true, description: 'ID сервисной точки'

    get('Получает список отзывов сервисной точки') do
      tags 'Reviews'
      description 'Возвращает список отзывов для указанной сервисной точки'
      operationId 'getServicePointReviews'
      produces 'application/json'

      parameter name: :rating, in: :query, type: :integer, required: false, description: 'Фильтр по рейтингу (1-5)'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Номер страницы'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Количество на странице'

      response(200, 'Отзывы сервисной точки') do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { '$ref': '#/components/schemas/Review' }
                 },
                 pagination: {
                   '$ref': '#/components/schemas/Pagination'
                 }
               }

        let(:service_point) { create(:service_point) }
        let(:service_point_id) { service_point.id }
        let(:page) { 1 }
        let(:per_page) { 20 }

        run_test!
      end

      response(404, 'Сервисная точка не найдена') do
        let(:service_point_id) { 0 }

        run_test!
      end
    end
  end
end 