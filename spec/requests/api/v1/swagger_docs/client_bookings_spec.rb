require 'swagger_helper'

RSpec.describe 'Client Bookings API', type: :request do
  path '/api/v1/client_bookings' do
    post 'Создание записи клиентом' do
      tags 'Client Bookings'
      description 'Создание новой записи на обслуживание клиентом (включая гостевые записи)'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :booking_data, in: :body, schema: {
        type: :object,
        properties: {
          client: {
            type: :object,
            properties: {
              first_name: { type: :string, description: 'Имя клиента', example: 'Иван' },
              last_name: { type: :string, description: 'Фамилия клиента', example: 'Иванов' },
              phone: { type: :string, description: 'Телефон клиента', example: '+380671234567' },
              email: { type: :string, description: 'Email клиента (опционально)', example: 'ivan@example.com' }
            },
            required: ['first_name', 'last_name', 'phone']
          },
          car: {
            type: :object,
            properties: {
              license_plate: { type: :string, description: 'Номер автомобиля', example: 'АА1234ВВ' },
              car_brand: { type: :string, description: 'Марка автомобиля', example: 'Toyota' },
              car_model: { type: :string, description: 'Модель автомобиля', example: 'Camry' },
              year: { type: :integer, description: 'Год выпуска', example: 2020 }
            },
            required: ['license_plate']
          },
          booking: {
            type: :object,
            properties: {
              service_point_id: { type: :integer, description: 'ID сервисной точки', example: 1 },
              booking_date: { type: :string, format: :date, description: 'Дата записи', example: '2025-01-27' },
              start_time: { type: :string, format: :time, description: 'Время начала', example: '10:00' },
              notes: { type: :string, description: 'Заметки к записи', example: 'Замена летней резины' }
            },
            required: ['service_point_id', 'booking_date', 'start_time']
          }
        },
        required: ['client', 'car', 'booking']
      }

      response '201', 'Запись успешно создана' do
        schema type: :object,
               properties: {
                 id: { type: :integer, description: 'ID записи' },
                 booking_date: { type: :string, format: :date, description: 'Дата записи' },
                 start_time: { type: :string, format: :time, description: 'Время начала' },
                 end_time: { type: :string, format: :time, description: 'Время окончания' },
                 status: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     name: { type: :string, example: 'pending' }
                   }
                 },
                 service_point: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     name: { type: :string }
                   }
                 },
                 client: {
                   type: :object,
                   properties: {
                     name: { type: :string, example: 'Иван Иванов' },
                     phone: { type: :string, example: '+380671234567' }
                   }
                 },
                 car_info: {
                   type: :object,
                   properties: {
                     license_plate: { type: :string, example: 'АА1234ВВ' },
                     type: { type: :string, example: 'Toyota Camry' }
                   }
                 },
                 total_price: { type: :string, example: '0.0' },
                 notes: { type: :string }
               }

        let(:booking_data) do
          {
            client: {
              first_name: 'Иван',
              last_name: 'Иванов',
              phone: '+380671234567',
              email: 'ivan@example.com'
            },
            car: {
              license_plate: 'АА1234ВВ',
              car_brand: 'Toyota',
              car_model: 'Camry',
              year: 2020
            },
            booking: {
              service_point_id: 1,
              booking_date: '2025-01-27',
              start_time: '10:00',
              notes: 'Замена летней резины'
            }
          }
        end

        run_test!
      end

      response '422', 'Ошибка валидации' do
        schema type: :object,
               properties: {
                 error: { type: :string, description: 'Описание ошибки' },
                 details: { type: :array, items: { type: :string }, description: 'Детали ошибок валидации' }
               }

        let(:booking_data) do
          {
            client: { first_name: '', last_name: 'Иванов', phone: '+380671234567' },
            car: { license_plate: 'АА1234ВВ' },
            booking: { service_point_id: 1, booking_date: '2025-01-27', start_time: '10:00' }
          }
        end

        run_test!
      end
    end
  end

  path '/api/v1/client_bookings/check_availability_for_booking' do
    post 'Проверка доступности времени для записи' do
      tags 'Client Bookings'
      description 'Проверяет доступность указанного времени для создания записи'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :availability_data, in: :body, schema: {
        type: :object,
        properties: {
          service_point_id: { type: :integer, description: 'ID сервисной точки', example: 1 },
          date: { type: :string, format: :date, description: 'Дата для проверки', example: '2025-01-27' },
          time: { type: :string, format: :time, description: 'Время для проверки', example: '10:00' },
          duration_minutes: { type: :integer, description: 'Длительность в минутах', example: 60 }
        },
        required: ['service_point_id', 'date', 'time', 'duration_minutes']
      }

      response '200', 'Информация о доступности' do
        schema type: :object,
               properties: {
                 available: { type: :boolean, description: 'Доступно ли время' },
                 total_posts: { type: :integer, description: 'Общее количество постов' },
                 occupied_posts: { type: :integer, description: 'Количество занятых постов' },
                 available_posts: { type: :integer, description: 'Количество доступных постов' },
                 reason: { type: :string, description: 'Причина недоступности (если available = false)' }
               }

        let(:availability_data) do
          {
            service_point_id: 1,
            date: '2025-01-27',
            time: '10:00',
            duration_minutes: 60
          }
        end

        run_test!
      end

      response '400', 'Неверные параметры' do
        schema type: :object,
               properties: {
                 error: { type: :string, description: 'Описание ошибки' }
               }

        let(:availability_data) { {} }

        run_test!
      end
    end
  end

  path '/api/v1/client_bookings/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'ID записи'

    get 'Получение информации о записи' do
      tags 'Client Bookings'
      description 'Получает подробную информацию о записи по ID'
      produces 'application/json'

      response '200', 'Информация о записи' do
        schema type: :object,
               properties: {
                 id: { type: :integer },
                 booking_date: { type: :string, format: :date },
                 start_time: { type: :string, format: :time },
                 end_time: { type: :string, format: :time },
                 status: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     name: { type: :string }
                   }
                 },
                 service_point: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     name: { type: :string },
                     address: { type: :string },
                     contact_phone: { type: :string }
                   }
                 },
                 client: {
                   type: :object,
                   properties: {
                     name: { type: :string },
                     phone: { type: :string }
                   }
                 },
                 car_info: {
                   type: :object,
                   properties: {
                     license_plate: { type: :string },
                     type: { type: :string }
                   }
                 },
                 total_price: { type: :string },
                 notes: { type: :string }
               }

        let(:id) { 1 }

        run_test!
      end

      response '404', 'Запись не найдена' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'Запись не найдена' }
               }

        let(:id) { 999999 }

        run_test!
      end
    end

    put 'Обновление записи' do
      tags 'Client Bookings'
      description 'Обновляет существующую запись (только в статусе pending)'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :booking_update, in: :body, schema: {
        type: :object,
        properties: {
          booking: {
            type: :object,
            properties: {
              booking_date: { type: :string, format: :date, description: 'Новая дата записи' },
              start_time: { type: :string, format: :time, description: 'Новое время начала' },
              notes: { type: :string, description: 'Обновленные заметки' }
            }
          }
        }
      }

      response '200', 'Запись успешно обновлена' do
        schema type: :object,
               properties: {
                 id: { type: :integer },
                 booking_date: { type: :string, format: :date },
                 start_time: { type: :string, format: :time },
                 end_time: { type: :string, format: :time },
                 notes: { type: :string }
               }

        let(:id) { 1 }
        let(:booking_update) do
          {
            booking: {
              booking_date: '2025-01-28',
              start_time: '11:00',
              notes: 'Обновленные заметки'
            }
          }
        end

        run_test!
      end

      response '403', 'Запрещено изменять запись' do
        schema type: :object,
               properties: {
                 error: { type: :string, description: 'Причина запрета' }
               }

        let(:id) { 1 }
        let(:booking_update) { { booking: { notes: 'Новые заметки' } } }

        run_test!
      end
    end
  end

  path '/api/v1/client_bookings/{id}/cancel' do
    parameter name: :id, in: :path, type: :integer, description: 'ID записи'

    delete 'Отмена записи клиентом' do
      tags 'Client Bookings'
      description 'Отменяет запись клиентом (не позднее чем за 2 часа до времени записи)'
      produces 'application/json'

      response '200', 'Запись успешно отменена' do
        schema type: :object,
               properties: {
                 id: { type: :integer },
                 status: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     name: { type: :string, example: 'canceled_by_client' }
                   }
                 },
                 canceled_at: { type: :string, format: :datetime }
               }

        let(:id) { 1 }

        run_test!
      end

      response '403', 'Отмена запрещена' do
        schema type: :object,
               properties: {
                 error: { type: :string, description: 'Причина запрета отмены' },
                 reason: { type: :string, description: 'Детальная причина' }
               }

        let(:id) { 1 }

        run_test!
      end
    end
  end

  path '/api/v1/client_bookings/{id}/reschedule' do
    parameter name: :id, in: :path, type: :integer, description: 'ID записи'

    post 'Перенос записи на новое время' do
      tags 'Client Bookings'
      description 'Переносит существующую запись на новую дату и время'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :reschedule_data, in: :body, schema: {
        type: :object,
        properties: {
          new_date: { type: :string, format: :date, description: 'Новая дата записи', example: '2025-01-28' },
          new_time: { type: :string, format: :time, description: 'Новое время записи', example: '14:00' }
        },
        required: ['new_date', 'new_time']
      }

      response '200', 'Запись успешно перенесена' do
        schema type: :object,
               properties: {
                 id: { type: :integer },
                 booking_date: { type: :string, format: :date },
                 start_time: { type: :string, format: :time },
                 end_time: { type: :string, format: :time },
                 old_date: { type: :string, format: :date, description: 'Предыдущая дата' },
                 old_time: { type: :string, format: :time, description: 'Предыдущее время' }
               }

        let(:id) { 1 }
        let(:reschedule_data) do
          {
            new_date: '2025-01-28',
            new_time: '14:00'
          }
        end

        run_test!
      end

      response '422', 'Новое время недоступно' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'Новое время недоступно' },
                 reason: { type: :string, description: 'Причина недоступности' }
               }

        let(:id) { 1 }
        let(:reschedule_data) do
          {
            new_date: '2025-01-28',
            new_time: '14:00'
          }
        end

        run_test!
      end

      response '400', 'Неверные параметры' do
        schema type: :object,
               properties: {
                 error: { type: :string, description: 'Описание ошибки' }
               }

        let(:id) { 1 }
        let(:reschedule_data) { {} }

        run_test!
      end
    end
  end
end 