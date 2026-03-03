module Api
  module V1
    class AdminController < ApiController
      skip_after_action :verify_authorized
      before_action :authenticate_request
      before_action :ensure_admin!

      private

      def ensure_admin!
        unless current_user&.admin?
          render json: { 
            error: 'Доступ запрещен. Требуются права администратора.',
            required_role: 'admin',
            current_role: current_user&.role || 'none'
          }, status: :forbidden
        end
      end

      def current_user_admin?
        current_user&.admin?
      end

      # Логирование админских действий
      def log_admin_action(action, resource = nil, details = {})
        Rails.logger.info({
          admin_action: action,
          admin_id: current_user&.id,
          admin_email: current_user&.email,
          resource: resource,
          details: details,
          ip_address: request.remote_ip,
          user_agent: request.user_agent,
          timestamp: Time.current.iso8601
        }.to_json)
      end

      # Обработка ошибок для админских действий
      def handle_admin_error(error, action)
        Rails.logger.error("Admin action '#{action}' failed: #{error.message}")
        Rails.logger.error(error.backtrace.join("\n"))
        
        render json: {
          error: "Ошибка выполнения административного действия: #{action}",
          details: Rails.env.development? ? error.message : 'Внутренняя ошибка сервера'
        }, status: :internal_server_error
      end
    end
  end
end