module Api
  module V1
    class ApiController < ApplicationController
      include Pagy::Backend
      before_action :authenticate_request
      
      protected
      
      # Метод для пагинации
      def paginate(collection)
        pagy, items = pagy(collection, page: params[:page], items: params[:per_page] || 20)
        { 
          data: items,
          pagination: {
            current_page: pagy.page,
            total_pages: pagy.pages,
            total_count: pagy.count,
            per_page: pagy.vars[:items]
          }
        }
      end
      
      # Параметры для сортировки
      def sort_params
        sort = params[:sort] || 'created_at'
        direction = params[:direction] || 'desc'
        { sort => direction }
      end
      
      # Логирование действий
      def log_action(action, entity_type, entity_id, old_value = nil, new_value = nil)
        SystemLog.create(
          user: current_user,
          action: action,
          entity_type: entity_type,
          entity_id: entity_id,
          old_value: old_value,
          new_value: new_value,
          ip_address: current_ip,
          user_agent: current_user_agent
        )
      end
    end
  end
end
