class Api::V1::BookingStatusesController < ApplicationController
  before_action :authenticate_request, except: [:index]
  
  # GET /api/v1/booking_statuses
  def index
    # ✅ Возвращаем статусы без привязки к старой таблице BookingStatus
    # Используем строковые ключи как основу для новой системы статусов
    statuses = [
      {
        key: 'pending',
        name: 'В ожидании',
        description: 'Бронирование создано, но не подтверждено',
        color: '#FFC107'
      },
      {
        key: 'confirmed',
        name: 'Подтверждено',
        description: 'Бронирование подтверждено',
        color: '#4CAF50'
      },
      {
        key: 'in_progress',
        name: 'В процессе',
        description: 'Обслуживание выполняется',
        color: '#2196F3'
      },
      {
        key: 'completed',
        name: 'Завершено',
        description: 'Обслуживание завершено',
        color: '#8BC34A'
      },
      {
        key: 'cancelled_by_client',
        name: 'Отменено клиентом',
        description: 'Бронирование отменено клиентом',
        color: '#F44336'
      },
      {
        key: 'cancelled_by_partner',
        name: 'Отменено партнером',
        description: 'Бронирование отменено партнером',
        color: '#9C27B0'
      },
      {
        key: 'no_show',
        name: 'Не явился',
        description: 'Клиент не явился на обслуживание',
        color: '#607D8B'
      }
    ]
    
    render json: statuses
  end
end 