module Api
  module V1
    class ApiController < ApplicationController
      include Pagy::Backend
      before_action :authenticate_request
      
      protected
      
      # Аутентификация только если токен присутствует (для публичных endpoint'ов)
      def authenticate_request_if_token_present
        return unless request.headers['Authorization'].present?
        authenticate_request
      end
      
      # Метод для пагинации
      def paginate(collection)
        page = params[:page].present? ? params[:page].to_i : 1
        per_page = params[:per_page].present? ? params[:per_page].to_i : 20
        
        # Ограничиваем per_page
        per_page = [per_page, 100].min
        per_page = [per_page, 1].max
        
        begin
          # Создаем Pagy с чистыми параметрами, используя :limit
          total_count = collection.count
          pagy_vars = {
            count: total_count,
            page: page,
            limit: per_page,  # Используем :limit вместо :items
            outset: 0
          }
          pagy = Pagy.new(**pagy_vars)
          
          offset = (pagy.page - 1) * pagy.vars[:limit]
          items = collection.offset(offset).limit(pagy.vars[:limit])
          
          { 
            data: items,
            pagination: {
              current_page: pagy.page,
              total_pages: pagy.pages,
              total_count: pagy.count,
              per_page: pagy.vars[:limit]
            }
          }
        rescue Pagy::OverflowError
          # Если запрошенная страница больше максимальной, возвращаем последнюю страницу
          total_count = collection.count
          total_pages = [(total_count.to_f / per_page).ceil, 1].max
          last_page_items = collection.offset((total_pages - 1) * per_page).limit(per_page)
          { 
            data: last_page_items,
            pagination: {
              current_page: total_pages,
              total_pages: total_pages,
              total_count: total_count,
              per_page: per_page
            }
          }
        end
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
