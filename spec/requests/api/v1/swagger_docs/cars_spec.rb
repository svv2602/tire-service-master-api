require 'swagger_helper'

RSpec.describe 'Cars API', type: :request do
  path '/api/v1/cars' do
    get('Получает список автомобилей пользователя') do
      tags 'Cars'
      description 'Возвращает список автомобилей текущего пользователя'
      operationId 'getUserCars'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'Список автомобилей') do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { '$ref': '#/components/schemas/Car' }
                 }
               }

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end

      response(401, 'Не авторизован') do
        schema '$ref' => '#/components/schemas/ErrorResponse'
        let(:Authorization) { 'Bearer invalid_token' }
        run_test!
      end
    end

    post('Добавляет новый автомобиль') do
      tags 'Cars'
      description 'Добавляет новый автомобиль в гараж пользователя'
      operationId 'createCar'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :car_params, in: :body, schema: {
        type: :object,
        properties: {
          car: {
            '$ref': '#/components/schemas/CarRequest'
          }
        },
        required: [:car]
      }

      response(201, 'Автомобиль добавлен') do
        schema type: :object,
               properties: {
                 data: { '$ref': '#/components/schemas/Car' },
                 message: { type: :string }
               }

        let(:user) { create(:user) }
        let(:car_brand) { create(:car_brand) }
        let(:car_model) { create(:car_model, car_brand: car_brand) }
        let(:car_type) { create(:car_type) }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        let(:car_params) do
          {
            car: {
              car_brand_id: car_brand.id,
              car_model_id: car_model.id,
              car_type_id: car_type.id,
              year: 2020,
              license_plate: 'AA1234BB',
              color: 'Черный',
              vin: '1HGCM82633A123456'
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['license_plate']).to eq('AA1234BB')
          expect(data['message']).to be_present
        end
      end

      response(422, 'Ошибка валидации') do
        schema '$ref' => '#/components/schemas/ValidationErrorResponse'

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        let(:car_params) do
          {
            car: {
              car_brand_id: nil,
              year: 'invalid_year'
            }
          }
        end

        run_test!
      end

      response(401, 'Не авторизован') do
        schema '$ref' => '#/components/schemas/ErrorResponse'
        let(:Authorization) { 'Bearer invalid_token' }
        let(:car_params) { { car: { license_plate: 'AA1234BB' } } }
        run_test!
      end
    end
  end

  path '/api/v1/cars/{id}' do
    parameter name: 'id', in: :path, type: :integer, description: 'ID автомобиля'

    get('Получает информацию об автомобиле') do
      tags 'Cars'
      description 'Возвращает детальную информацию об автомобиле пользователя'
      operationId 'getCar'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'Информация об автомобиле') do
        schema type: :object,
               properties: {
                 data: { '$ref': '#/components/schemas/CarDetailed' }
               }

        let(:user) { create(:user) }
        let(:car) { create(:car, user: user) }
        let(:id) { car.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['id']).to eq(car.id)
          expect(data['data']['license_plate']).to eq(car.license_plate)
        end
      end

      response(404, 'Автомобиль не найден') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:id) { 99999 }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test!
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:other_user) { create(:user) }
        let(:car) { create(:car, user: other_user) }
        let(:id) { car.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test!
      end

      response(401, 'Не авторизован') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:car) { create(:car) }
        let(:id) { car.id }
        let(:Authorization) { 'Bearer invalid_token' }

        run_test!
      end
    end

    patch('Обновляет информацию об автомобиле') do
      tags 'Cars'
      description 'Обновляет информацию об автомобиле пользователя'
      operationId 'updateCar'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :car_params, in: :body, schema: {
        type: :object,
        properties: {
          car: {
            '$ref': '#/components/schemas/CarRequest'
          }
        },
        required: [:car]
      }

      response(200, 'Автомобиль обновлен') do
        schema type: :object,
               properties: {
                 data: { '$ref': '#/components/schemas/Car' },
                 message: { type: :string }
               }

        let(:user) { create(:user) }
        let(:car) { create(:car, user: user) }
        let(:id) { car.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        let(:car_params) do
          {
            car: {
              license_plate: 'XX9999YY',
              color: 'Красный',
              year: 2021
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['license_plate']).to eq('XX9999YY')
          expect(data['data']['color']).to eq('Красный')
        end
      end

      response(422, 'Ошибка валидации') do
        schema '$ref' => '#/components/schemas/ValidationErrorResponse'

        let(:user) { create(:user) }
        let(:car) { create(:car, user: user) }
        let(:id) { car.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        let(:car_params) do
          {
            car: {
              year: 1800 # Слишком старый год
            }
          }
        end

        run_test!
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:other_user) { create(:user) }
        let(:car) { create(:car, user: other_user) }
        let(:id) { car.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        let(:car_params) { { car: { color: 'Синий' } } }

        run_test!
      end

      response(401, 'Не авторизован') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:car) { create(:car) }
        let(:id) { car.id }
        let(:Authorization) { 'Bearer invalid_token' }
        let(:car_params) { { car: { color: 'Синий' } } }

        run_test!
      end
    end

    delete('Удаляет автомобиль') do
      tags 'Cars'
      description 'Удаляет автомобиль из гаража пользователя'
      operationId 'deleteCar'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'Автомобиль удален') do
        schema type: :object,
               properties: {
                 message: { type: :string, example: 'Автомобиль успешно удален' }
               }

        let(:user) { create(:user) }
        let(:car) { create(:car, user: user) }
        let(:id) { car.id }
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
        let(:car) { create(:car, user: other_user) }
        let(:id) { car.id }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test!
      end

      response(404, 'Автомобиль не найден') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:id) { 99999 }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test!
      end

      response(401, 'Не авторизован') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:car) { create(:car) }
        let(:id) { car.id }
        let(:Authorization) { 'Bearer invalid_token' }

        run_test!
      end
    end
  end
end 