module Api
  module V1
    class OperatorsController < ApiController
      before_action :set_partner, only: [:create, :index], if: -> { params[:partner_id].present? }
      before_action :set_operator, only: [:update, :destroy]
      before_action :set_operator_with_partner, only: [:update, :destroy], if: -> { params[:partner_id].present? }

      # Получить всех сотрудников-операторов партнера ИЛИ всех операторов (для админов)
      def index
        if params[:partner_id].present?
          # Операторы конкретного партнера
          operators = Operator.includes(:user, :partner)
            .where(partner_id: @partner.id)
          render json: operators, each_serializer: OperatorSerializer
        else
          # Все операторы (для админов)
          authorize Operator, :index?
          
          # Параметры фильтрации и пагинации
          page = [params[:page].to_i, 1].max
          per_page = [[params[:per_page].to_i, 20].max, 100].min
          
          # Базовый запрос
          operators_scope = Operator.includes(:user, :partner, operator_service_points: :service_point)
          
          # Фильтрация
          if params[:search].present?
            search_term = "%#{params[:search]}%"
            operators_scope = operators_scope.joins(:user)
              .where(
                "users.first_name ILIKE ? OR users.last_name ILIKE ? OR users.email ILIKE ? OR users.phone ILIKE ?",
                search_term, search_term, search_term, search_term
              )
          end
          
          if params[:partner_id].present?
            operators_scope = operators_scope.where(partner_id: params[:partner_id])
          end
          
          if params[:is_active].present?
            is_active = params[:is_active] == 'true'
            operators_scope = operators_scope.where(is_active: is_active)
          end
          
          # Пагинация
          total_count = operators_scope.count
          total_pages = (total_count.to_f / per_page).ceil
          operators = operators_scope
            .order(created_at: :desc)
            .offset((page - 1) * per_page)
            .limit(per_page)
          
          render json: {
            data: operators.map { |operator| OperatorSerializer.new(operator).as_json },
            pagination: {
              current_page: page,
              total_pages: total_pages,
              total_count: total_count,
              per_page: per_page
            }
          }
        end
      end

      # Добавить нового сотрудника-оператора
      def create
        authorize Operator, :create?
        
        Rails.logger.info "=== CREATE OPERATOR DEBUG ==="
        Rails.logger.info "params[:partner_id]: #{params[:partner_id]}"
        Rails.logger.info "@partner: #{@partner.inspect}"
        
        user_params = params.require(:user).permit(:first_name, :last_name, :email, :phone, :password, :is_active)
        operator_params = params.require(:operator).permit(:position, :access_level, :is_active)

        # Используем переданные значения активности или по умолчанию true
        user_is_active = user_params[:is_active].nil? ? true : user_params[:is_active]
        operator_is_active = operator_params[:is_active].nil? ? true : operator_params[:is_active]

        user = User.new(user_params.merge(role_id: 3, is_active: user_is_active))
        if user.save
          operator = Operator.new(operator_params.merge(user: user, partner: @partner, is_active: operator_is_active))
          if operator.save
            render json: operator, serializer: OperatorSerializer, status: :created
          else
            user.destroy
            render json: { errors: operator.errors.full_messages }, status: :unprocessable_entity
          end
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # Редактировать данные сотрудника-оператора
      def update
        Rails.logger.info "=== UPDATE OPERATOR ==="
        Rails.logger.info "Params: #{params.inspect}"
        Rails.logger.info "Operator ID: #{params[:id]}"
        Rails.logger.info "Current user: #{@current_user&.email}"
        
        user_params = params[:user]&.permit(:first_name, :last_name, :email, :phone, :password, :is_active) || {}
        operator_params = params[:operator]&.permit(:position, :access_level, :is_active) || {}

        Rails.logger.info "User params: #{user_params}"
        Rails.logger.info "Operator params: #{operator_params}"

        success = true
        if user_params.present?
          Rails.logger.info "Updating user with: #{user_params}"
          success = @operator.user.update(user_params)
          Rails.logger.info "User update success: #{success}"
          Rails.logger.info "User errors: #{@operator.user.errors.full_messages}" unless success
        end
        
        if operator_params.present? && success
          Rails.logger.info "Updating operator with: #{operator_params}"
          success = @operator.update(operator_params) && success
          Rails.logger.info "Operator update success: #{success}"
          Rails.logger.info "Operator errors: #{@operator.errors.full_messages}" unless success
        end
        
        if success
          Rails.logger.info "=== UPDATE SUCCESS ==="
          render json: @operator, serializer: OperatorSerializer
        else
          Rails.logger.error "=== UPDATE FAILED ==="
          render json: { errors: @operator.errors.full_messages + @operator.user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # Удалить или деактивировать сотрудника-оператора
      def destroy
        Rails.logger.info "=== DELETE OPERATOR ==="
        Rails.logger.info "Operator ID: #{params[:id]}"
        Rails.logger.info "Current user: #{@current_user&.email}"
        Rails.logger.info "Operator: #{@operator.inspect}"
        
        begin
          if has_related_records?(@operator.user)
            Rails.logger.info "Has related records, deactivating..."
            @operator.update(is_active: false)
            @operator.user.update(is_active: false)
            Rails.logger.info "=== DEACTIVATION SUCCESS ==="
            render json: { message: 'Пользователь деактивирован, так как есть связанные записи.' }
          else
            Rails.logger.info "No related records, deleting..."
            @operator.user.destroy
            @operator.destroy
            Rails.logger.info "=== DELETION SUCCESS ==="
            render json: { message: 'Пользователь полностью удалён.' }
          end
        rescue => e
          Rails.logger.error "=== DELETE/DEACTIVATE FAILED ==="
          Rails.logger.error "Error: #{e.message}"
          Rails.logger.error "Backtrace: #{e.backtrace.first(5)}"
          render json: { error: "Ошибка при удалении/деактивации: #{e.message}" }, status: :internal_server_error
        end
      end

      private

      def set_partner
        @partner = Partner.find(params[:partner_id])
      end

      def set_operator
        @operator = Operator.find(params[:id])
      end
      
      def set_operator_with_partner
        @operator = Operator.includes(:partner).find(params[:id])
        @partner = @operator.partner
      end

      # Проверка наличия связанных записей у пользователя
      def has_related_records?(user)
        # Проверяем бронирования через клиента (если пользователь также является клиентом)
        return true if user.client&.bookings&.exists?
        
        # Проверяем бронирования операторов (если оператор создавал/обрабатывал бронирования)
        # return true if Booking.where(created_by: user.id).exists?
        
        false
      rescue => e
        Rails.logger.error "Ошибка при проверке связанных записей для пользователя #{user.id}: #{e.message}"
        # В случае ошибки возвращаем true для безопасности (деактивируем вместо удаления)
        true
      end
    end
  end
end 