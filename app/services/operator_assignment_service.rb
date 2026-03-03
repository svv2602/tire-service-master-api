class OperatorAssignmentService
  include Auditable

  def self.assign_operator_to_points(operator, service_point_ids, assigned_by_user)
    new.assign_operator_to_points(operator, service_point_ids, assigned_by_user)
  end

  def self.unassign_operator_from_points(operator, service_point_ids, unassigned_by_user)
    new.unassign_operator_from_points(operator, service_point_ids, unassigned_by_user)
  end

  def self.bulk_assign_operators(service_point, operator_ids, assigned_by_user)
    new.bulk_assign_operators(service_point, operator_ids, assigned_by_user)
  end

  def self.auto_assign_new_operator(operator, assigned_by_user)
    new.auto_assign_new_operator(operator, assigned_by_user)
  end

  def assign_operator_to_points(operator, service_point_ids, assigned_by_user)
    service_point_ids = Array(service_point_ids).map(&:to_i)
    results = { success: [], failed: [], errors: [] }

    ActiveRecord::Base.transaction do
      service_point_ids.each do |point_id|
        begin
          # Валидация принадлежности точки партнеру
          service_point = ServicePoint.find(point_id)
          unless validate_point_belongs_to_operator_partner(operator, service_point)
            results[:failed] << point_id
            results[:errors] << "Сервисная точка #{point_id} не принадлежит партнеру оператора"
            next
          end

          # Проверка активности оператора и точки
          unless validate_operator_and_point_active(operator, service_point)
            results[:failed] << point_id
            results[:errors] << "Оператор или сервисная точка #{point_id} неактивны"
            next
          end

          # Создание или обновление привязки
          assignment = OperatorServicePoint.find_or_initialize_by(
            operator: operator,
            service_point: service_point
          )

          if assignment.persisted? && assignment.is_active?
            results[:failed] << point_id
            results[:errors] << "Оператор уже назначен на точку #{point_id}"
            next
          end

          assignment.assign_attributes(
            assigned_at: Time.current,
            is_active: true
          )

          if assignment.save
            results[:success] << point_id

            # Логирование назначения
            AuditLogJob.log_assignment(
              user_id: assigned_by_user.id,
              operator_id: operator.id,
              service_point_ids: [service_point.id],
              ip_address: CurrentContext.ip_address,
              user_agent: CurrentContext.user_agent,
              additional_data: {
                action_type: 'assign',
                assignment_id: assignment.id
              }
            )

            # Отправка уведомления оператору
            send_assignment_notification(operator, service_point, 'assigned')
          else
            results[:failed] << point_id
            results[:errors] << "Ошибка сохранения привязки для точки #{point_id}: #{assignment.errors.full_messages.join(', ')}"
          end

        rescue ActiveRecord::RecordNotFound
          results[:failed] << point_id
          results[:errors] << "Сервисная точка #{point_id} не найдена"
        rescue => e
          results[:failed] << point_id
          results[:errors] << "Неожиданная ошибка для точки #{point_id}: #{e.message}"
        end
      end
    end

    results
  end

  def unassign_operator_from_points(operator, service_point_ids, unassigned_by_user)
    service_point_ids = Array(service_point_ids).map(&:to_i)
    results = { success: [], failed: [], errors: [] }

    ActiveRecord::Base.transaction do
      service_point_ids.each do |point_id|
        begin
          service_point = ServicePoint.find(point_id)
          
          assignment = OperatorServicePoint.find_by(
            operator: operator,
            service_point: service_point,
            is_active: true
          )

          unless assignment
            results[:failed] << point_id
            results[:errors] << "Активная привязка для точки #{point_id} не найдена"
            next
          end

          if assignment.update(is_active: false)
            results[:success] << point_id

            # Логирование отзыва назначения
            AuditLogJob.log_unassignment(
              user_id: unassigned_by_user.id,
              operator_id: operator.id,
              service_point_ids: [service_point.id],
              ip_address: CurrentContext.ip_address,
              user_agent: CurrentContext.user_agent,
              additional_data: {
                action_type: 'unassign',
                assignment_id: assignment.id
              }
            )

            # Отправка уведомления оператору
            send_assignment_notification(operator, service_point, 'unassigned')
          else
            results[:failed] << point_id
            results[:errors] << "Ошибка отзыва привязки для точки #{point_id}: #{assignment.errors.full_messages.join(', ')}"
          end

        rescue ActiveRecord::RecordNotFound
          results[:failed] << point_id
          results[:errors] << "Сервисная точка #{point_id} не найдена"
        rescue => e
          results[:failed] << point_id
          results[:errors] << "Неожиданная ошибка для точки #{point_id}: #{e.message}"
        end
      end
    end

    results
  end

  def bulk_assign_operators(service_point, operator_ids, assigned_by_user)
    operator_ids = Array(operator_ids).map(&:to_i)
    results = { success: [], failed: [], errors: [] }

    ActiveRecord::Base.transaction do
      operator_ids.each do |operator_id|
        begin
          operator = Operator.find(operator_id)
          
          # Валидация принадлежности оператора партнеру точки
          unless operator.partner_id == service_point.partner_id
            results[:failed] << operator_id
            results[:errors] << "Оператор #{operator_id} не принадлежит партнеру точки"
            next
          end

          # Проверка активности
          unless validate_operator_and_point_active(operator, service_point)
            results[:failed] << operator_id
            results[:errors] << "Оператор #{operator_id} или сервисная точка неактивны"
            next
          end

          # Создание привязки
          assignment = OperatorServicePoint.find_or_initialize_by(
            operator: operator,
            service_point: service_point
          )

          if assignment.persisted? && assignment.is_active?
            results[:failed] << operator_id
            results[:errors] << "Оператор #{operator_id} уже назначен на эту точку"
            next
          end

          assignment.assign_attributes(
            assigned_at: Time.current,
            is_active: true
          )

          if assignment.save
            results[:success] << operator_id

            # Логирование
            AuditLogJob.log_assignment(
              user_id: assigned_by_user.id,
              operator_id: operator.id,
              service_point_ids: [service_point.id],
              ip_address: CurrentContext.ip_address,
              user_agent: CurrentContext.user_agent,
              additional_data: {
                action_type: 'bulk_assign',
                assignment_id: assignment.id
              }
            )

            # Уведомление
            send_assignment_notification(operator, service_point, 'assigned')
          else
            results[:failed] << operator_id
            results[:errors] << "Ошибка назначения оператора #{operator_id}: #{assignment.errors.full_messages.join(', ')}"
          end

        rescue ActiveRecord::RecordNotFound
          results[:failed] << operator_id
          results[:errors] << "Оператор #{operator_id} не найден"
        rescue => e
          results[:failed] << operator_id
          results[:errors] << "Неожиданная ошибка для оператора #{operator_id}: #{e.message}"
        end
      end
    end

    results
  end

  def auto_assign_new_operator(operator, assigned_by_user)
    return { success: [], failed: [], errors: ['Оператор не найден'] } unless operator

    # Получаем все активные точки партнера
    partner_points = operator.partner.service_points.active

    if partner_points.empty?
      return { 
        success: [], 
        failed: [], 
        errors: ['У партнера нет активных сервисных точек для автоназначения'] 
      }
    end

    # Назначаем на все точки партнера
    point_ids = partner_points.pluck(:id)
    result = assign_operator_to_points(operator, point_ids, assigned_by_user)

    # Логирование автоназначения
    AuditLogJob.log_assignment(
      user_id: assigned_by_user.id,
      operator_id: operator.id,
      service_point_ids: result[:success],
      ip_address: CurrentContext.ip_address,
      user_agent: CurrentContext.user_agent,
      additional_data: {
        action_type: 'auto_assign',
        total_points: point_ids.count,
        successful_assignments: result[:success].count,
        failed_assignments: result[:failed].count
      }
    )

    result
  end

  private

  def validate_point_belongs_to_operator_partner(operator, service_point)
    operator.partner_id == service_point.partner_id
  end

  def validate_operator_and_point_active(operator, service_point)
    operator.is_active? && service_point.is_active?
  end



  def send_assignment_notification(operator, service_point, action_type)
    # Отправляем уведомление через существующую систему уведомлений
    case action_type
    when 'assigned'
      NotificationService.send_operator_assignment_notification(
        operator,
        service_point,
        'assigned'
      )
    when 'unassigned'
      NotificationService.send_operator_assignment_notification(
        operator,
        service_point,
        'unassigned'
      )
    end
  rescue => e
    Rails.logger.error "Ошибка отправки уведомления оператору #{operator.id}: #{e.message}"
  end
end 