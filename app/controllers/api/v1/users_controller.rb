module Api
  module V1
    class UsersController < ApiController
      before_action :set_user, only: [:show, :update, :destroy]
      before_action :authorize_admin, except: [:show, :update]
      
      # GET /api/v1/users
      def index
        @users = User.all
        
        # Фильтрация по роли
        @users = @users.with_role(params[:role]) if params[:role].present?
        
        # Фильтрация по активности
        @users = @users.where(is_active: params[:is_active]) if params[:is_active].present?
        
        # Поиск по email или имени
        if params[:query].present?
          @users = @users.where("email LIKE ? OR first_name LIKE ? OR last_name LIKE ?", 
                              "%#{params[:query]}%", "%#{params[:query]}%", "%#{params[:query]}%")
        end
        
        # Сортировка
        @users = @users.order(sort_params)
        
        render json: paginate(@users)
      end
      
      # GET /api/v1/users/:id
      def show
        authorize @user
        render json: @user
      end
      
      # POST /api/v1/users
      def create
        @user = User.new(user_params)
        authorize @user
        
        if @user.save
          log_action('create', 'user', @user.id, nil, @user.as_json)
          render json: @user, status: :created
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
          render json: @user
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
        # Не позволяем менять роль через этот контроллер
        params.require(:user).permit(
          :email, :phone, :password, :password_confirmation, :first_name, 
          :last_name, :middle_name, :is_active
        )
      end
    end
  end
end
