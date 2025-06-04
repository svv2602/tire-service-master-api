require 'swagger_helper'

RSpec.describe 'Catalogs API', type: :request do
  # Регионы
  path '/api/v1/catalogs/regions' do
    get('Получает список регионов') do
      tags 'Catalogs'
      description 'Возвращает список всех доступных регионов'
      operationId 'getRegions'
      produces 'application/json'

      response(200, 'Список регионов') do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { '$ref': '#/components/schemas/Region' }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end
  end

  # Города
  path '/api/v1/catalogs/cities' do
    get('Получает список городов') do
      tags 'Catalogs'
      description 'Возвращает список городов с возможностью фильтрации по региону'
      operationId 'getCities'
      produces 'application/json'

      parameter name: :region_id, in: :query, type: :integer, required: false, description: 'ID региона для фильтрации'

      response(200, 'Список городов') do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { '$ref': '#/components/schemas/City' }
                 }
               }

        let(:region) { create(:region) }
        let(:region_id) { region.id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end
  end

  # Марки автомобилей
  path '/api/v1/catalogs/car_brands' do
    get('Получает список марок автомобилей') do
      tags 'Catalogs'
      description 'Возвращает список всех марок автомобилей'
      operationId 'getCarBrands'
      produces 'application/json'

      parameter name: :query, in: :query, type: :string, required: false, description: 'Поиск по названию марки'

      response(200, 'Список марок автомобилей') do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { '$ref': '#/components/schemas/CarBrand' }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end
  end

  # Модели автомобилей
  path '/api/v1/catalogs/car_models' do
    get('Получает список моделей автомобилей') do
      tags 'Catalogs'
      description 'Возвращает список моделей автомобилей с возможностью фильтрации по марке'
      operationId 'getCarModels'
      produces 'application/json'

      parameter name: :car_brand_id, in: :query, type: :integer, required: false, description: 'ID марки для фильтрации'
      parameter name: :query, in: :query, type: :string, required: false, description: 'Поиск по названию модели'

      response(200, 'Список моделей автомобилей') do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { '$ref': '#/components/schemas/CarModel' }
                 }
               }

        let(:car_brand) { create(:car_brand) }
        let(:car_brand_id) { car_brand.id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end
  end

  # Типы автомобилей
  path '/api/v1/catalogs/car_types' do
    get('Получает список типов автомобилей') do
      tags 'Catalogs'
      description 'Возвращает список типов автомобилей (седан, хэтчбек, кроссовер и т.д.)'
      operationId 'getCarTypes'
      produces 'application/json'

      response(200, 'Список типов автомобилей') do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { '$ref': '#/components/schemas/CarType' }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end
  end

  # Типы шин
  path '/api/v1/catalogs/tire_types' do
    get('Получает список типов шин') do
      tags 'Catalogs'
      description 'Возвращает список типов шин (летние, зимние, всесезонные)'
      operationId 'getTireTypes'
      produces 'application/json'

      response(200, 'Список типов шин') do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { '$ref': '#/components/schemas/TireType' }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end
  end

  # Категории услуг
  path '/api/v1/catalogs/service_categories' do
    get('Получает список категорий услуг') do
      tags 'Catalogs'
      description 'Возвращает список категорий услуг (шиномонтаж, балансировка и т.д.)'
      operationId 'getServiceCategories'
      produces 'application/json'

      response(200, 'Список категорий услуг') do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { '$ref': '#/components/schemas/ServiceCategory' }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end
  end

  # Услуги
  path '/api/v1/catalogs/services' do
    get('Получает список услуг') do
      tags 'Catalogs'
      description 'Возвращает список услуг с возможностью фильтрации по категории'
      operationId 'getServices'
      produces 'application/json'

      parameter name: :service_category_id, in: :query, type: :integer, required: false, description: 'ID категории для фильтрации'
      parameter name: :query, in: :query, type: :string, required: false, description: 'Поиск по названию услуги'

      response(200, 'Список услуг') do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { '$ref': '#/components/schemas/Service' }
                 }
               }

        let(:service_category) { create(:service_category) }
        let(:service_category_id) { service_category.id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end
  end

  # Управление регионами (админ)
  path '/api/v1/admin/catalogs/regions' do
    post('Создает новый регион') do
      tags 'Catalogs (Admin)'
      description 'Создает новый регион в системе'
      operationId 'createRegion'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :region_params, in: :body, schema: {
        type: :object,
        properties: {
          region: {
            '$ref': '#/components/schemas/RegionRequest'
          }
        },
        required: [:region]
      }

      response(201, 'Регион создан') do
        schema type: :object,
               properties: {
                 data: { '$ref': '#/components/schemas/Region' },
                 message: { type: :string }
               }

        let(:admin_user) { create(:user, :admin) }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }
        let(:region_params) do
          {
            region: {
              name: 'Киевская область',
              code: 'UA-KV'
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['name']).to eq('Киевская область')
        end
      end

      response(422, 'Ошибка валидации') do
        schema '$ref' => '#/components/schemas/ValidationErrorResponse'

        let(:admin_user) { create(:user, :admin) }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }
        let(:region_params) do
          {
            region: {
              name: ''
            }
          }
        end

        run_test!
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        let(:region_params) { { region: { name: 'Test' } } }

        run_test!
      end
    end
  end

  # Управление марками автомобилей (админ)
  path '/api/v1/admin/catalogs/car_brands' do
    post('Создает новую марку автомобиля') do
      tags 'Catalogs (Admin)'
      description 'Создает новую марку автомобиля в системе'
      operationId 'createCarBrand'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :car_brand_params, in: :body, schema: {
        type: :object,
        properties: {
          car_brand: {
            '$ref': '#/components/schemas/CarBrandRequest'
          }
        },
        required: [:car_brand]
      }

      response(201, 'Марка автомобиля создана') do
        schema type: :object,
               properties: {
                 data: { '$ref': '#/components/schemas/CarBrand' },
                 message: { type: :string }
               }

        let(:admin_user) { create(:user, :admin) }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }
        let(:car_brand_params) do
          {
            car_brand: {
              name: 'Tesla',
              country: 'USA'
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['name']).to eq('Tesla')
        end
      end

      response(422, 'Ошибка валидации') do
        schema '$ref' => '#/components/schemas/ValidationErrorResponse'

        let(:admin_user) { create(:user, :admin) }
        let(:Authorization) { "Bearer #{generate_jwt_token(admin_user)}" }
        let(:car_brand_params) do
          {
            car_brand: {
              name: ''
            }
          }
        end

        run_test!
      end

      response(403, 'Недостаточно прав доступа') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }
        let(:car_brand_params) { { car_brand: { name: 'Test' } } }

        run_test!
      end
    end
  end
end 