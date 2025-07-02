class Api::V1::BookingStatusesController < ApplicationController
  before_action :authenticate_request, except: [:index]
  
  # GET /api/v1/booking_statuses
  def index
    statuses = BookingStatus.active.sorted.select(:id, :name, :description, :color)
    
    # Маппинг статусов на русский язык
    status_translations = {
      'pending' => 'В ожидании',
      'confirmed' => 'Подтверждено',
      'in_progress' => 'В процессе',
      'completed' => 'Завершено',
      'canceled_by_client' => 'Отменено клиентом',
      'canceled_by_partner' => 'Отменено партнером',
      'no_show' => 'Не явился'
    }
    
    render json: statuses.map { |status|
      {
        id: status.id,
        name: status_translations[status.name] || status.name,
        description: status.description,
        color: status.color
      }
    }
  end
end 