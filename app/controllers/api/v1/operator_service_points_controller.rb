class Api::V1::OperatorServicePointsController < ApplicationController
  before_action :authenticate_request
  before_action :set_operator, only: [:index, :create, :bulk_assign]
  before_action :set_operator_service_point, only: [:show, :destroy, :update]
  before_action :set_audit_context

  # GET /api/v1/operators/:operator_id/service_points
  # Получить все привязки оператора к сервисным точкам
  def index
    authorize @operator, :show?
    
    assignments = @operator.operator_service_points
                           .includes(:service_point)
                           .order(:created_at)
    
    assignments = assignments.where(is_active: params[:active]) if params[:active].present?
    
    render json: {
      data: assignments.map { |assignment| serialize_assignment(assignment) },
      meta: {
        total: assignments.count,
        active: @operator.operator_service_points.active.count,
        inactive: @operator.operator_service_points.inactive.count
      }
    }
  end

  # GET /api/v1/operator_service_points/:id
  # Получить конкретную привязку
  def show
    authorize @assignment, :show?
    
    render json: {
      data: serialize_assignment(@assignment)
    }
  end

  # POST /api/v1/operators/:operator_id/service_points
  # Назначить оператора на сервисную точку
  def create
    authorize @operator, :assign_to_service_points?
    
    service_point = ServicePoint.find(params[:service_point_id])
    
    # Проверяем, что точка принадлежит тому же партнеру
    unless service_point.partner_id == @operator.partner_id
      render json: {
        error: 'Оператор может быть назначен только на точки своего партнера',
        code: 'PARTNER_MISMATCH'
      }, status: :forbidden
      return
    end
    
    # Проверяем, нет ли уже активной привязки
    existing_assignment = @operator.operator_service_points
                                  .find_by(service_point: service_point)
    
    if existing_assignment&.is_active?
      render json: {
        error: 'Оператор уже назначен на эту сервисную точку',
        code: 'ALREADY_ASSIGNED'
      }, status: :unprocessable_entity
      return
    end
    
    assignment = if existing_assignment
                   # Реактивируем существующую привязку
                   existing_assignment.tap do |a|
                     a.update!(is_active: true, assigned_at: Time.current)
                   end
                 else
                   # Создаем новую привязку
                   @operator.operator_service_points.create!(
                     service_point: service_point,
                     assigned_at: Time.current,
                     is_active: true
                   )
                 end
    
    # Логируем назначение
    SystemLog.log_assign(
      current_user,
      @operator,
      service_point,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
    
    render json: {
      data: serialize_assignment(assignment),
      message: 'Оператор успешно назначен на сервисную точку'
    }, status: :created
  end

  # DELETE /api/v1/operator_service_points/:id
  # Отозвать назначение оператора с сервисной точки
  def destroy
    authorize @assignment, :destroy?
    
    operator = @assignment.operator
    service_point = @assignment.service_point
    
    @assignment.update!(is_active: false)
    
    # Логируем отзыв назначения
    SystemLog.log_unassign(
      current_user,
      operator,
      service_point,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
    
    render json: {
      data: serialize_assignment(@assignment.reload),
      message: 'Назначение оператора отозвано'
    }
  end

  # PATCH /api/v1/operator_service_points/:id
  # Активировать/деактивировать привязку
  def update
    authorize @assignment, :update?
    
    @assignment.update!(assignment_params)
    
    action = @assignment.is_active? ? 'активировано' : 'деактивировано'
    
    render json: {
      data: serialize_assignment(@assignment),
      message: "Назначение #{action}"
    }
  end

  # POST /api/v1/operators/:operator_id/service_points/bulk_assign
  # Массовое назначение оператора на несколько точек
  def bulk_assign
    authorize @operator, :assign_to_service_points?
    
    service_point_ids = params[:service_point_ids] || []
    
    if service_point_ids.empty?
      render json: {
        error: 'Не указаны ID сервисных точек',
        code: 'MISSING_SERVICE_POINT_IDS'
      }, status: :bad_request
      return
    end
    
    service_points = ServicePoint.where(id: service_point_ids, partner_id: @operator.partner_id)
    
    if service_points.count != service_point_ids.count
      render json: {
        error: 'Некоторые сервисные точки не найдены или принадлежат другому партнеру',
        code: 'INVALID_SERVICE_POINTS'
      }, status: :unprocessable_entity
      return
    end
    
    results = []
    errors = []
    
    ActiveRecord::Base.transaction do
      service_points.each do |service_point|
        begin
          existing_assignment = @operator.operator_service_points
                                        .find_by(service_point: service_point)
          
          if existing_assignment&.is_active?
            errors << {
              service_point_id: service_point.id,
              service_point_name: service_point.name,
              error: 'Уже назначен'
            }
            next
          end
          
          assignment = if existing_assignment
                         existing_assignment.tap do |a|
                           a.update!(is_active: true, assigned_at: Time.current)
                         end
                       else
                         @operator.operator_service_points.create!(
                           service_point: service_point,
                           assigned_at: Time.current,
                           is_active: true
                         )
                       end
          
          results << serialize_assignment(assignment)
          
          # Логируем каждое назначение
          SystemLog.log_assign(
            current_user,
            @operator,
            service_point,
            ip_address: request.remote_ip,
            user_agent: request.user_agent
          )
          
        rescue => e
          errors << {
            service_point_id: service_point.id,
            service_point_name: service_point.name,
            error: e.message
          }
        end
      end
    end
    
    render json: {
      data: results,
      errors: errors,
      meta: {
        total_requested: service_point_ids.count,
        successful: results.count,
        failed: errors.count
      },
      message: "Обработано #{results.count} из #{service_point_ids.count} назначений"
    }
  end

  private

  def set_operator
    @operator = Operator.find(params[:operator_id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      error: 'Оператор не найден',
      code: 'OPERATOR_NOT_FOUND'
    }, status: :not_found
  end

  def set_operator_service_point
    @assignment = OperatorServicePoint.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      error: 'Назначение не найдено',
      code: 'ASSIGNMENT_NOT_FOUND'
    }, status: :not_found
  end

  def assignment_params
    params.require(:operator_service_point).permit(:is_active)
  end

  def serialize_assignment(assignment)
    {
      id: assignment.id,
      operator_id: assignment.operator_id,
      service_point_id: assignment.service_point_id,
      service_point_name: assignment.service_point.name,
      service_point_address: assignment.service_point.address,
      partner_id: assignment.service_point.partner_id,
      partner_name: assignment.service_point.partner.name,
      is_active: assignment.is_active,
      assigned_at: assignment.assigned_at&.iso8601,
      created_at: assignment.created_at.iso8601,
      updated_at: assignment.updated_at.iso8601
    }
  end

  def set_audit_context
    CurrentContext.audit_user = current_user
    CurrentContext.ip_address = request.remote_ip
    CurrentContext.user_agent = request.user_agent
  end
end
