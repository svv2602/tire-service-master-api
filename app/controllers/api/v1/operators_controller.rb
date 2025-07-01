module Api
  module V1
    class OperatorsController < ApiController
      before_action :set_partner, only: [:index, :create]
      before_action :set_operator, only: [:update, :destroy]

      # Получить всех сотрудников-операторов партнера
      def index
        operators = Operator.includes(:user)
          .where(partner_id: @partner.id)
        render json: operators.as_json(include: { user: { only: [:id, :first_name, :last_name, :email, :phone, :is_active] } })
      end

      # Добавить нового сотрудника-оператора
      def create
        user_params = params.require(:user).permit(:first_name, :last_name, :email, :phone, :password)
        operator_params = params.require(:operator).permit(:position, :access_level)

        user = User.new(user_params.merge(role_id: 3, is_active: true))
        if user.save
          operator = Operator.new(operator_params.merge(user: user, partner: @partner, is_active: true))
          if operator.save
            render json: operator.as_json(include: { user: { only: [:id, :first_name, :last_name, :email, :phone, :is_active] } }), status: :created
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
        user_params = params.require(:user).permit(:first_name, :last_name, :email, :phone, :password, :is_active)
        operator_params = params.require(:operator).permit(:position, :access_level, :is_active)

        success = @operator.user.update(user_params) && @operator.update(operator_params)
        if success
          render json: @operator.as_json(include: { user: { only: [:id, :first_name, :last_name, :email, :phone, :is_active] } })
        else
          render json: { errors: @operator.errors.full_messages + @operator.user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # Удалить или деактивировать сотрудника-оператора
      def destroy
        if has_related_records?(@operator.user)
          @operator.update(is_active: false)
          @operator.user.update(is_active: false)
          render json: { message: 'Пользователь деактивирован, так как есть связанные записи.' }
        else
          @operator.user.destroy
          @operator.destroy
          render json: { message: 'Пользователь полностью удалён.' }
        end
      end

      private

      def set_partner
        @partner = Partner.find(params[:partner_id])
      end

      def set_operator
        @operator = Operator.find(params[:id])
      end

      # Проверка наличия связанных записей у пользователя
      def has_related_records?(user)
        # Пример: бронирования, смены, логи и т.д.
        user.bookings.exists? || user.system_logs.exists?
      end
    end
  end
end 