require 'swagger_helper'

RSpec.describe 'Dashboard API', type: :request do
  path '/api/v1/dashboard/stats' do
    get('Получает общую статистику системы') do
      tags 'Dashboard'
      description 'Возвращает основные метрики и статистику для дашборда'
      operationId 'getDashboardStats'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :period, in: :query, type: :string, required: false, 
                description: 'Период для статистики', enum: ['day', 'week', 'month', 'year']

      response(200, 'Статистика дашборда') do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     bookings: {
                       type: :object,
                       properties: {
                         total: { type: :integer, example: 1250 },
                         completed: { type: :integer, example: 1100 },
                         cancelled: { type: :integer, example: 50 },
                         pending: { type: :integer, example: 100 },
                         growth: { type: :number, format: :float, example: 12.5 }
                       }
                     },
                     revenue: {
                       type: :object,
                       properties: {
                         total: { type: :number, format: :float, example: 125000.0 },
                         current_period: { type: :number, format: :float, example: 25000.0 },
                         growth: { type: :number, format: :float, example: 15.3 }
                       }
                     },
                     service_points: {
                       type: :object,
                       properties: {
                         total: { type: :integer, example: 45 },
                         active: { type: :integer, example: 42 },
                         new_this_period: { type: :integer, example: 3 }
                       }
                     },
                     users: {
                       type: :object,
                       properties: {
                         total: { type: :integer, example: 2500 },
                         new_this_period: { type: :integer, example: 150 },
                         active: { type: :integer, example: 1800 }
                       }
                     },
                     reviews: {
                       type: :object,
                       properties: {
                         total: { type: :integer, example: 890 },
                         average_rating: { type: :number, format: :float, example: 4.3 },
                         new_this_period: { type: :integer, example: 45 }
                       }
                     }
                   }
                 }
               }

        let(:admin_user) { create(:user, :admin) }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }
        let(:period) { 'month' }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['bookings']).to include('total', 'completed', 'growth')
          expect(data['data']['revenue']).to include('total', 'current_period', 'growth')
          expect(data['data']['service_points']).to include('total', 'active')
          expect(data['data']['users']).to include('total', 'new_this_period')
          expect(data['data']['reviews']).to include('total', 'average_rating')
        end
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test!
      end

      response(401, 'Не авторизован') do
        schema '$ref' => '#/components/schemas/ErrorResponse'
        let(:Authorization) { 'Bearer invalid_token' }
        run_test!
      end
    end
  end

  path '/api/v1/dashboard/charts/bookings' do
    get('Получает данные для графика бронирований') do
      tags 'Dashboard'
      description 'Возвращает данные для построения графиков статистики бронирований'
      operationId 'getBookingsChart'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :period, in: :query, type: :string, required: false,
                description: 'Период для графика', enum: ['week', 'month', 'quarter', 'year']
      parameter name: :group_by, in: :query, type: :string, required: false,
                description: 'Группировка данных', enum: ['day', 'week', 'month']

      response(200, 'Данные графика бронирований') do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     labels: {
                       type: :array,
                       items: { type: :string },
                       example: ['2024-01-01', '2024-01-02', '2024-01-03']
                     },
                     datasets: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           label: { type: :string, example: 'Завершенные' },
                           data: {
                             type: :array,
                             items: { type: :integer },
                             example: [15, 22, 18]
                           },
                           backgroundColor: { type: :string, example: '#4CAF50' }
                         }
                       }
                     }
                   }
                 }
               }

        let(:admin_user) { create(:user, :admin) }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }
        let(:period) { 'month' }
        let(:group_by) { 'day' }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['labels']).to be_an(Array)
          expect(data['data']['datasets']).to be_an(Array)
        end
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test!
      end
    end
  end

  path '/api/v1/dashboard/charts/revenue' do
    get('Получает данные для графика доходов') do
      tags 'Dashboard'
      description 'Возвращает данные для построения графиков доходов'
      operationId 'getRevenueChart'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :period, in: :query, type: :string, required: false,
                description: 'Период для графика', enum: ['week', 'month', 'quarter', 'year']
      parameter name: :group_by, in: :query, type: :string, required: false,
                description: 'Группировка данных', enum: ['day', 'week', 'month']

      response(200, 'Данные графика доходов') do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     labels: {
                       type: :array,
                       items: { type: :string },
                       example: ['Январь', 'Февраль', 'Март']
                     },
                     datasets: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           label: { type: :string, example: 'Доходы' },
                           data: {
                             type: :array,
                             items: { type: :number },
                             example: [15000.50, 22300.75, 18900.25]
                           },
                           backgroundColor: { type: :string, example: '#2196F3' }
                         }
                       }
                     }
                   }
                 }
               }

        let(:admin_user) { create(:user, :admin) }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }
        let(:period) { 'quarter' }
        let(:group_by) { 'month' }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['labels']).to be_an(Array)
          expect(data['data']['datasets']).to be_an(Array)
          expect(data['data']['datasets'].first['data']).to be_an(Array)
        end
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test!
      end
    end
  end

  path '/api/v1/dashboard/top-services' do
    get('Получает топ популярных услуг') do
      tags 'Dashboard'
      description 'Возвращает список самых популярных услуг'
      operationId 'getTopServices'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Количество услуг'
      parameter name: :period, in: :query, type: :string, required: false,
                description: 'Период для анализа', enum: ['week', 'month', 'quarter', 'year']

      response(200, 'Топ услуг') do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       service: { '$ref': '#/components/schemas/Service' },
                       bookings_count: { type: :integer, example: 150 },
                       revenue: { type: :number, format: :float, example: 75000.0 },
                       growth: { type: :number, format: :float, example: 12.5 }
                     }
                   }
                 }
               }

        let(:admin_user) { create(:user, :admin) }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }
        let(:limit) { 10 }
        let(:period) { 'month' }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          if data['data'].any?
            expect(data['data'].first).to include('service', 'bookings_count', 'revenue')
          end
        end
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test!
      end
    end
  end

  path '/api/v1/dashboard/partner/{partner_id}/stats' do
    parameter name: 'partner_id', in: :path, type: :integer, description: 'ID партнера'

    get('Получает статистику для конкретного партнера') do
      tags 'Dashboard'
      description 'Возвращает детальную статистику для партнера'
      operationId 'getPartnerStats'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :period, in: :query, type: :string, required: false,
                description: 'Период для статистики', enum: ['day', 'week', 'month', 'year']

      response(200, 'Статистика партнера') do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     partner: { '$ref': '#/components/schemas/Partner' },
                     stats: {
                       type: :object,
                       properties: {
                         service_points_count: { type: :integer, example: 5 },
                         total_bookings: { type: :integer, example: 250 },
                         completed_bookings: { type: :integer, example: 230 },
                         total_revenue: { type: :number, format: :float, example: 125000.0 },
                         average_rating: { type: :number, format: :float, example: 4.5 },
                         reviews_count: { type: :integer, example: 89 }
                       }
                     }
                   }
                 }
               }

        let(:partner) { create(:partner) }
        let(:partner_user) { create(:user, :partner, partner: partner) }
        let(:partner_id) { partner.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(partner_user)}" }
        let(:period) { 'month' }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['partner']['id']).to eq(partner.id)
          expect(data['data']['stats']).to include('service_points_count', 'total_bookings')
        end
      end

      response(404, 'Партнер не найден') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:admin_user) { create(:user, :admin) }
        let(:partner_id) { 99999 }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }

        run_test!
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:partner) { create(:partner) }
        let(:other_partner) { create(:partner) }
        let(:other_partner_user) { create(:user, :partner, partner: other_partner) }
        let(:partner_id) { partner.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(other_partner_user)}" }

        run_test!
      end

      response(401, 'Не авторизован') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:partner) { create(:partner) }
        let(:partner_id) { partner.id }
        let(:Authorization) { 'Bearer invalid_token' }

        run_test!
      end
    end
  end
end 