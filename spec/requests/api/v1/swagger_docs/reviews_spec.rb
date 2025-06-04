require 'swagger_helper'

RSpec.describe 'Reviews API', type: :request do
  path '/api/v1/reviews' do
    get('Получает список отзывов') do
      tags 'Reviews'
      description 'Возвращает список отзывов с возможностью фильтрации'
      operationId 'getReviews'
      produces 'application/json'

      parameter name: :service_point_id, in: :query, type: :integer, required: false, description: 'ID сервисной точки'
      parameter name: :rating, in: :query, type: :integer, required: false, description: 'Фильтр по рейтингу (1-5)'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Номер страницы'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Количество на странице'

      response(200, 'Список отзывов') do
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

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['pagination']).to include('current_page', 'total_pages')
        end
      end
    end

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
            '$ref': '#/components/schemas/ReviewRequest'
          }
        },
        required: [:review]
      }

      response(201, 'Отзыв создан') do
        schema type: :object,
               properties: {
                 data: { '$ref': '#/components/schemas/Review' },
                 message: { type: :string }
               }

        let(:user) { create(:user) }
        let(:booking) { create(:booking, :completed, user: user) }
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

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['rating']).to eq(5)
          expect(data['data']['comment']).to include('Отличный сервис')
          expect(data['message']).to be_present
        end
      end

      response(422, 'Ошибка валидации') do
        schema '$ref' => '#/components/schemas/ValidationErrorResponse'

        let(:user) { create(:user) }
        let(:booking) { create(:booking, user: user) }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        let(:review_params) do
          {
            review: {
              booking_id: booking.id,
              rating: 6, # Некорректный рейтинг
              comment: ''
            }
          }
        end

        run_test!
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:other_user) { create(:user) }
        let(:booking) { create(:booking, :completed, user: other_user) }
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
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:booking) { create(:booking, :completed) }
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

  path '/api/v1/reviews/{id}' do
    parameter name: 'id', in: :path, type: :integer, description: 'ID отзыва'

    get('Получает информацию об отзыве') do
      tags 'Reviews'
      description 'Возвращает детальную информацию об отзыве'
      operationId 'getReview'
      produces 'application/json'

      response(200, 'Информация об отзыве') do
        schema type: :object,
               properties: {
                 data: { '$ref': '#/components/schemas/ReviewDetailed' }
               }

        let(:review) { create(:review) }
        let(:id) { review.id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['id']).to eq(review.id)
          expect(data['data']['rating']).to be_present
          expect(data['data']['comment']).to be_present
        end
      end

      response(404, 'Отзыв не найден') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:id) { 99999 }

        run_test!
      end
    end

    patch('Обновляет отзыв') do
      tags 'Reviews'
      description 'Обновляет отзыв (только автор может редактировать свой отзыв)'
      operationId 'updateReview'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :review_params, in: :body, schema: {
        type: :object,
        properties: {
          review: {
            '$ref': '#/components/schemas/ReviewUpdateRequest'
          }
        },
        required: [:review]
      }

      response(200, 'Отзыв обновлен') do
        schema type: :object,
               properties: {
                 data: { '$ref': '#/components/schemas/Review' },
                 message: { type: :string }
               }

        let(:user) { create(:user) }
        let(:booking) { create(:booking, :completed, user: user) }
        let(:review) { create(:review, booking: booking) }
        let(:id) { review.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        let(:review_params) do
          {
            review: {
              rating: 4,
              comment: 'Обновленный отзыв - хороший сервис',
              recommend: true
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['rating']).to eq(4)
          expect(data['data']['comment']).to include('Обновленный отзыв')
        end
      end

      response(422, 'Ошибка валидации') do
        schema '$ref' => '#/components/schemas/ValidationErrorResponse'

        let(:user) { create(:user) }
        let(:booking) { create(:booking, :completed, user: user) }
        let(:review) { create(:review, booking: booking) }
        let(:id) { review.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        let(:review_params) do
          {
            review: {
              rating: 0, # Некорректный рейтинг
              comment: ''
            }
          }
        end

        run_test!
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:other_user) { create(:user) }
        let(:booking) { create(:booking, :completed, user: other_user) }
        let(:review) { create(:review, booking: booking) }
        let(:id) { review.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        let(:review_params) { { review: { rating: 3 } } }

        run_test!
      end

      response(401, 'Не авторизован') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:review) { create(:review) }
        let(:id) { review.id }
        let(:Authorization) { 'Bearer invalid_token' }
        let(:review_params) { { review: { rating: 3 } } }

        run_test!
      end
    end

    delete('Удаляет отзыв') do
      tags 'Reviews'
      description 'Удаляет отзыв (только автор или администратор)'
      operationId 'deleteReview'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'Отзыв удален') do
        schema type: :object,
               properties: {
                 message: { type: :string, example: 'Отзыв успешно удален' }
               }

        let(:user) { create(:user) }
        let(:booking) { create(:booking, :completed, user: user) }
        let(:review) { create(:review, booking: booking) }
        let(:id) { review.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['message']).to include('удален')
        end
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:other_user) { create(:user) }
        let(:booking) { create(:booking, :completed, user: other_user) }
        let(:review) { create(:review, booking: booking) }
        let(:id) { review.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test!
      end

      response(404, 'Отзыв не найден') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:id) { 99999 }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test!
      end

      response(401, 'Не авторизован') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:review) { create(:review) }
        let(:id) { review.id }
        let(:Authorization) { 'Bearer invalid_token' }

        run_test!
      end
    end
  end

  path '/api/v1/service_points/{service_point_id}/reviews' do
    parameter name: 'service_point_id', in: :path, type: :integer, description: 'ID сервисной точки'

    get('Получает отзывы для сервисной точки') do
      tags 'Reviews'
      description 'Возвращает все отзывы для конкретной сервисной точки'
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
                 },
                 stats: {
                   type: :object,
                   properties: {
                     average_rating: { type: :number, format: :float, example: 4.5 },
                     total_reviews: { type: :integer, example: 150 },
                     rating_distribution: {
                       type: :object,
                       properties: {
                         '5': { type: :integer, example: 80 },
                         '4': { type: :integer, example: 40 },
                         '3': { type: :integer, example: 20 },
                         '2': { type: :integer, example: 7 },
                         '1': { type: :integer, example: 3 }
                       }
                     }
                   }
                 }
               }

        let(:service_point) { create(:service_point) }
        let(:service_point_id) { service_point.id }
        let(:page) { 1 }
        let(:per_page) { 20 }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['pagination']).to include('current_page', 'total_pages')
          expect(data['stats']).to include('average_rating', 'total_reviews')
        end
      end

      response(404, 'Сервисная точка не найдена') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:service_point_id) { 99999 }

        run_test!
      end
    end
  end
end 