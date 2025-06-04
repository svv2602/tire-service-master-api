require 'swagger_helper'

RSpec.describe 'Service Posts with Custom Schedule API', type: :request do
  path '/api/v1/partners/{partner_id}/service_points' do
    parameter name: 'partner_id', in: :path, type: :integer, description: 'ID партнера'

    post('Создает сервисную точку с постами с индивидуальными расписаниями') do
      tags 'Service Points', 'Service Posts'
      description 'Создает новую сервисную точку с постами обслуживания, включая возможность настройки индивидуальных расписаний для каждого поста'
      operationId 'createServicePointWithCustomSchedulePosts'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :service_point_params, in: :body, schema: {
        type: :object,
        properties: {
          service_point: {
            type: :object,
            properties: {
              name: {
                type: :string,
                description: 'Название сервисной точки',
                example: 'Автосервис с индивидуальными расписаниями'
              },
              address: {
                type: :string,
                description: 'Адрес сервисной точки',
                example: 'ул. Примерная, 123'
              },
              city_id: {
                type: :integer,
                description: 'ID города',
                example: 1
              },
              service_posts_attributes: {
                type: :array,
                description: 'Посты обслуживания с возможностью индивидуальных расписаний',
                items: {
                  type: :object,
                  properties: {
                    name: {
                      type: :string,
                      description: 'Название поста',
                      example: 'Пост экспресс-обслуживания'
                    },
                    post_number: {
                      type: :integer,
                      description: 'Номер поста',
                      example: 1
                    },
                    slot_duration: {
                      type: :integer,
                      description: 'Длительность слота в минутах',
                      example: 30
                    },
                    has_custom_schedule: {
                      type: :boolean,
                      description: 'Имеет ли пост индивидуальное расписание',
                      example: true
                    },
                    working_days: {
                      type: :object,
                      description: 'Рабочие дни недели для индивидуального расписания',
                      example: {
                        monday: true,
                        tuesday: false,
                        wednesday: true,
                        thursday: true,
                        friday: false,
                        saturday: false,
                        sunday: false
                      }
                    },
                    custom_hours: {
                      type: :object,
                      description: 'Индивидуальные часы работы поста',
                      properties: {
                        start: {
                          type: :string,
                          description: 'Время начала работы в формате HH:MM',
                          example: '10:00'
                        },
                        end: {
                          type: :string,
                          description: 'Время окончания работы в формате HH:MM',
                          example: '19:00'
                        }
                      }
                    }
                  },
                  required: [:name, :post_number, :slot_duration]
                }
              }
            },
            required: [:name, :address, :city_id]
          }
        },
        required: [:service_point]
      }

      response(201, 'Сервисная точка с постами создана успешно') do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     id: { type: :integer, description: 'ID сервисной точки' },
                     name: { type: :string, description: 'Название сервисной точки' },
                     service_posts: {
                       type: :array,
                       description: 'Посты обслуживания',
                       items: {
                         type: :object,
                         properties: {
                           id: { type: :integer },
                           post_number: { type: :integer },
                           name: { type: :string },
                           has_custom_schedule: { type: :boolean },
                           working_days: { type: :object },
                           custom_hours: { type: :object },
                           working_days_list: {
                             type: :array,
                             items: { type: :string }
                           }
                         }
                       }
                     }
                   }
                 }
               }

        let(:partner_id) { create(:partner).id }
        let(:city) { create(:city) }
        let(:service_point_params) do
          {
            service_point: {
              name: 'Тестовая точка с индивидуальными расписаниями',
              address: 'ул. Тестовая, 1',
              city_id: city.id,
              service_posts_attributes: [
                {
                  name: 'Обычный пост',
                  post_number: 1,
                  slot_duration: 60,
                  has_custom_schedule: false
                },
                {
                  name: 'Пост с индивидуальным расписанием',
                  post_number: 2,
                  slot_duration: 30,
                  has_custom_schedule: true,
                  working_days: {
                    monday: true,
                    tuesday: false,
                    wednesday: true,
                    thursday: true,
                    friday: false,
                    saturday: false,
                    sunday: false
                  },
                  custom_hours: {
                    start: '10:00',
                    end: '19:00'
                  }
                }
              ]
            }
          }
        end

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['service_posts']).to be_an(Array)
          expect(data['data']['service_posts'].length).to eq(2)
          
          # Проверяем пост с индивидуальным расписанием
          custom_post = data['data']['service_posts'].find { |p| p['post_number'] == 2 }
          expect(custom_post['has_custom_schedule']).to be_truthy
          expect(custom_post['working_days']).to include('monday' => true, 'wednesday' => true)
          expect(custom_post['custom_hours']).to include('start' => '10:00', 'end' => '19:00')
        end
      end

      response(422, 'Ошибка валидации') do
        schema type: :object,
               properties: {
                 errors: {
                   type: :object,
                   description: 'Ошибки валидации'
                 }
               }

        let(:partner_id) { create(:partner).id }
        let(:service_point_params) do
          {
            service_point: {
              name: 'Тестовая точка',
              address: 'ул. Тестовая, 1',
              city_id: 999, # Несуществующий город
              service_posts_attributes: [
                {
                  name: 'Пост с некорректным расписанием',
                  post_number: 1,
                  slot_duration: 30,
                  has_custom_schedule: true,
                  working_days: {
                    monday: false,
                    tuesday: false,
                    wednesday: false,
                    thursday: false,
                    friday: false,
                    saturday: false,
                    sunday: false
                  }, # Нет рабочих дней
                  custom_hours: {
                    start: '19:00',
                    end: '10:00' # Время начала больше времени окончания
                  }
                }
              ]
            }
          }
        end

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{generate_jwt_token(user)}" }

        run_test!
      end

      response(401, 'Не авторизован') do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:partner_id) { create(:partner).id }
        let(:service_point_params) { { service_point: { name: 'Test' } } }
        let(:Authorization) { 'Bearer invalid_token' }

        run_test!
      end
    end
  end
end 