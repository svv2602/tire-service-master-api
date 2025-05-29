module Api
  module V1
    class ApiController < ApplicationController
      include Pagy::Backend
      before_action :authenticate_request
      
      protected
      
      # Метод для пагинации
      def paginate(collection)
        page = params[:page].to_i if params[:page].present?
        per_page = (params[:per_page] || 20).to_i
        
        begin
          pagy, items = pagy(collection, page: page, items: per_page)
          { 
            data: items,
            pagination: {
              current_page: pagy.page,
              total_pages: [pagy.pages, 1].max, # Минимум 1 страница если есть данные
              total_count: pagy.count,
              per_page: pagy.vars[:items]
            }
          }
        rescue Pagy::OverflowError
          # Если запрошенная страница больше максимальной, возвращаем пустой список
          total_count = collection.count
          total_pages = [(total_count.to_f / per_page).ceil, 1].max # Минимум 1 страница если есть данные
          { 
            data: [],
            pagination: {
              current_page: [page, total_pages].min,
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
