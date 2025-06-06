module Api
  module V1
    class UsersController < ApiController
      before_action :set_user, only: [:show, :update, :destroy]
      before_action :authorize_admin, except: [:show, :update, :me]
      
      # GET /api/v1/users/me
      def me
        render json: current_user
      end
      
      # GET /api/v1/users
      def index
        @users = User.all
        
        # Фильтрация по роли
        @users = @users.with_role(params[:role]) if params[:role].present?
        
        # Фильтрация по активности
        if params[:active].present?
          @users = @users.where(is_active: params[:active] == 'true')
        end
        
        # Поиск по email, имени или номеру телефона
        if params[:query].present?
          query_downcase = params[:query].downcase
          @users = @users.where("LOWER(email) LIKE ? OR LOWER(first_name) LIKE ? OR LOWER(last_name) LIKE ? OR phone LIKE ?", 
                               "%#{query_downcase}%", "%#{query_downcase}%", "%#{query_downcase}%", "%#{params[:query]}%")
        end
        
        result = paginate(@users.order(created_at: :desc))
        render json: result
      end
      
      # GET /api/v1/users/:id
      def show
        authorize @user
        render json: { data: @user }
      end
      
      # POST /api/v1/users
      def create
        @user = User.new(user_params)
        authorize @user
        
        if @user.save
          log_action('create', 'user', @user.id, nil, @user.as_json)
          render json: { data: @user }, status: :created
        else
          render json: { errors: @user.errors }, status: :unprocessable_entity
        end
      end
      
      # PUT /api/v1/users/:id
      def update
        authorize @user
        
        old_values = @user.as_json
        
        if @user.update(user_update_params)
          log_action('update', 'user', @user.id, old_values, @user.as_json)
          render json: { data: @user }
        else
          render json: { errors: @user.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/users/:id
      def destroy
        authorize @user
        
        old_values = @user.as_json
        
        if @user.update(is_active: false)
          log_action('deactivate', 'user', @user.id, old_values, @user.as_json)
          render json: { message: 'User deactivated successfully' }
        else
          render json: { errors: @user.errors }, status: :unprocessable_entity
        end
      end
      
      private
      
      def set_user
        @user = User.find(params[:id])
      end
      
      def authorize_admin
        authorize User, :manage?
      end
      
      def user_params
        params.require(:user).permit(
          :email, :phone, :password, :password_confirmation, :first_name, 
          :last_name, :middle_name, :role_id, :is_active
        )
      end
      
      def user_update_params
        # Разрешаем изменение роли через обновление
        params.require(:user).permit(
          :email, :phone, :password, :password_confirmation, :first_name, 
          :last_name, :middle_name, :role_id, :is_active
        )
      end
      
      def sort_params
        sort_by = params[:sort_by] || 'created_at'
        sort_order = params[:sort_order] || 'desc'
        
        # Ограничиваем возможные поля для сортировки
        allowed_fields = %w[id email first_name last_name created_at updated_at is_active]
        sort_by = 'created_at' unless allowed_fields.include?(sort_by)
        
        # Ограничиваем порядок сортировки
        sort_order = 'desc' unless %w[asc desc].include?(sort_order)
        
        "#{sort_by} #{sort_order}"
      end
    end
  end
end
