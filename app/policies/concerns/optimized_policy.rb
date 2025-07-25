module OptimizedPolicy
  extend ActiveSupport::Concern
  
  # Кэш для часто используемых данных пользователя
  included do
    # Кэшируем связанные данные пользователя на время запроса
    def cached_user_data
      @cached_user_data ||= begin
        return {} unless user.present?
        
        data = {
          id: user.id,
          role: user.role&.name,
          is_admin: user.admin?,
          is_partner: user.partner?,
          is_manager: user.manager?,
          is_client: user.client?,
          is_operator: user.operator?
        }
        
        # Кэшируем связанные объекты для избежания N+1
        if user.partner?
          data[:partner_id] = user.partner&.id
          data[:partner_service_point_ids] = Rails.cache.fetch(
            "user_#{user.id}_partner_service_points", 
            expires_in: 5.minutes
          ) do
            user.partner&.service_points&.pluck(:id) || []
          end
        end
        
        if user.manager?
          data[:manager_id] = user.manager&.id
          data[:manager_service_point_ids] = Rails.cache.fetch(
            "user_#{user.id}_manager_service_points", 
            expires_in: 5.minutes
          ) do
            ManagerServicePoint.where(manager_id: user.manager&.id)
                              .pluck(:service_point_id)
          end
        end
        
        if user.operator?
          data[:operator_id] = user.operator&.id
          data[:operator_service_point_ids] = Rails.cache.fetch(
            "user_#{user.id}_operator_service_points", 
            expires_in: 5.minutes
          ) do
            OperatorServicePoint.where(operator_id: user.operator&.id, is_active: true)
                               .pluck(:service_point_id)
          end
        end
        
        if user.client?
          data[:client_id] = user.client&.id
        end
        
        data
      end
    end
    
    # Быстрая проверка доступа к сервисной точке
    def can_access_service_point?(service_point_id)
      return true if cached_user_data[:is_admin]
      
      service_point_id = service_point_id.to_i
      
      if cached_user_data[:is_partner]
        return cached_user_data[:partner_service_point_ids].include?(service_point_id)
      end
      
      if cached_user_data[:is_manager]
        return cached_user_data[:manager_service_point_ids].include?(service_point_id)
      end
      
      if cached_user_data[:is_operator]
        return cached_user_data[:operator_service_point_ids].include?(service_point_id)
      end
      
      false
    end
    
    # Быстрая проверка принадлежности партнеру
    def belongs_to_user_partner?(partner_id)
      return true if cached_user_data[:is_admin]
      return false unless cached_user_data[:is_partner]
      
      cached_user_data[:partner_id] == partner_id.to_i
    end
    
    # Оптимизированные scope'ы для изоляции данных
    def optimized_scope_for_service_points(base_scope)
      return base_scope.all if cached_user_data[:is_admin]
      
      if cached_user_data[:is_partner]
        return base_scope.where(partner_id: cached_user_data[:partner_id])
      end
      
      if cached_user_data[:is_manager]
        return base_scope.where(id: cached_user_data[:manager_service_point_ids])
      end
      
      if cached_user_data[:is_operator]
        return base_scope.where(id: cached_user_data[:operator_service_point_ids])
      end
      
      # Для клиентов и неавторизованных - только доступные для бронирования
      base_scope.available_for_booking
    end
    
    def optimized_scope_for_bookings(base_scope)
      return base_scope.all if cached_user_data[:is_admin]
      
      if cached_user_data[:is_partner]
        return base_scope.joins(:service_point)
                        .where(service_points: { partner_id: cached_user_data[:partner_id] })
      end
      
      if cached_user_data[:is_manager]
        return base_scope.where(service_point_id: cached_user_data[:manager_service_point_ids])
      end
      
      if cached_user_data[:is_operator]
        return base_scope.where(service_point_id: cached_user_data[:operator_service_point_ids])
      end
      
      if cached_user_data[:is_client]
        return base_scope.where(client_id: cached_user_data[:client_id])
      end
      
      base_scope.none
    end
    
    def optimized_scope_for_reviews(base_scope)
      return base_scope.all if cached_user_data[:is_admin]
      
      if cached_user_data[:is_partner]
        return base_scope.joins(:service_point)
                        .where(service_points: { partner_id: cached_user_data[:partner_id] })
      end
      
      if cached_user_data[:is_manager]
        return base_scope.where(service_point_id: cached_user_data[:manager_service_point_ids])
      end
      
      if cached_user_data[:is_operator]
        return base_scope.where(service_point_id: cached_user_data[:operator_service_point_ids])
      end
      
      if cached_user_data[:is_client]
        return base_scope.where(client_id: cached_user_data[:client_id])
      end
      
      # Для неавторизованных - только опубликованные
      base_scope.where(is_published: true)
    end
    
    # Инвалидация кэша при изменении ролей/назначений
    def invalidate_user_cache!
      return unless user.present?
      
      Rails.cache.delete("user_#{user.id}_partner_service_points")
      Rails.cache.delete("user_#{user.id}_manager_service_points")
      Rails.cache.delete("user_#{user.id}_operator_service_points")
      @cached_user_data = nil
    end
  end
  
  class_methods do
    # Массовая проверка доступа для коллекций
    def batch_access_check(user, resource_ids, resource_type)
      return resource_ids if user&.admin?
      
      case resource_type
      when :service_points
        if user&.partner?
          ServicePoint.where(id: resource_ids, partner_id: user.partner&.id).pluck(:id)
        elsif user&.manager?
          manager_point_ids = ManagerServicePoint.where(manager_id: user.manager&.id)
                                                 .pluck(:service_point_id)
          resource_ids & manager_point_ids
        elsif user&.operator?
          operator_point_ids = OperatorServicePoint.where(operator_id: user.operator&.id, is_active: true)
                                                  .pluck(:service_point_id)
          resource_ids & operator_point_ids
        else
          []
        end
      when :bookings
        if user&.client?
          Booking.where(id: resource_ids, client_id: user.client&.id).pluck(:id)
        else
          []
        end
      else
        []
      end
    end
  end
end 