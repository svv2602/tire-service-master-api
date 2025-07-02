module Api
  module V1
    class ManagersController < ApiController
      before_action :set_manager, only: [:show, :update, :destroy]
      before_action :set_partner, only: [:index, :create, :create_test]
      before_action :authorize_admin, except: [:index, :show, :create_test]
      skip_before_action :authenticate_request, only: [:index, :create_test]
      
      # GET /api/v1/partners/:partner_id/managers
      def index
        @managers = @partner.managers.includes(:user)
        
        # Поиск по имени или email менеджера
        if params[:query].present?
          @managers = @managers.joins(:user).where(
            "users.email LIKE ? OR users.first_name LIKE ? OR users.last_name LIKE ?", 
            "%#{params[:query]}%", "%#{params[:query]}%", "%#{params[:query]}%"
          )
        end
        
        # Пагинация
        page = [params[:page].to_i, 1].max  # Минимум 1
        per_page = (params[:per_page] || 10).to_i
        offset = (page - 1) * per_page
        
        total_count = @managers.count
        @managers = @managers.offset(offset).limit(per_page)
        
        # Если нет менеджеров, возвращаем пустой массив
        if @managers.empty?
          render json: {
            managers: [],
            total_items: 0
          }
          return
        end
        
        render json: {
          managers: @managers.as_json(include: { 
            user: { only: [:id, :email, :phone, :first_name, :last_name] },
            service_points: { only: [:id, :name] }
          }),
          total_items: total_count
        }
      end
      
      # GET /api/v1/partners/:partner_id/managers/:id
      def show
        render json: @manager.as_json(include: { 
          user: { only: [:id, :email, :phone, :first_name, :last_name] },
          service_points: { only: [:id, :name] }
        })
      end
      
      # POST /api/v1/partners/:partner_id/managers
      def create
        ActiveRecord::Base.transaction do
          # Сначала создаем пользователя, если user_id не указан
          if params[:user_id].blank? && params[:user].present?
            user_params = params.require(:user).permit(:email, :password, :phone, :first_name, :last_name, :middle_name)
            @user = User.new(user_params)
            @user.role = UserRole.find_by(name: 'manager')
            @user.save!
            
            user_id = @user.id
          else
            user_id = params[:user_id]
          end
          
          # Затем создаем менеджера
          @manager = @partner.managers.new(manager_params)
          @manager.user_id = user_id
          @manager.save!
          
          # Если указаны сервисные точки, связываем их с менеджером
          if params[:service_point_ids].present?
            service_point_ids = params[:service_point_ids].is_a?(Array) ? params[:service_point_ids] : params[:service_point_ids].split(',')
            service_point_ids.each do |service_point_id|
              unless @partner.service_points.exists?(id: service_point_id)
                raise ActiveRecord::RecordNotFound, "Service point #{service_point_id} not found or does not belong to this partner"
              end
              @manager.manager_service_points.create!(service_point_id: service_point_id)
            end
          end
        end
        
        render json: @manager.as_json(include: { 
          user: { only: [:id, :email, :phone, :first_name, :last_name] },
          service_points: { only: [:id, :name] }
        }), status: :created
        
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors }, status: :unprocessable_entity
      rescue ActiveRecord::RecordNotFound => e
        render json: { error: e.message }, status: :not_found
      end
      
      # POST /api/v1/partners/:partner_id/managers/create_test
      def create_test
        ActiveRecord::Base.transaction do
          # Создаем пользователя
          @user = User.create!(
            email: "manager_test_#{Time.now.to_i}@example.com",
            password: 'password',
            password_confirmation: 'password',
            first_name: 'Тест',
            last_name: 'Менеджер',
            phone: "+38067#{Random.rand(1000000..9999999)}",
            role: UserRole.find_by(name: 'manager')
          )
          
          # Создаем менеджера
          @manager = @partner.managers.create!(
            user_id: @user.id,
            position: "Тестовый менеджер",
            access_level: 1
          )
          
          # Получаем ID сервисных точек партнера
          service_point_ids = @partner.service_points.limit(3).pluck(:id)
          
          # Связываем менеджера с сервисными точками
          service_point_ids.each do |service_point_id|
            @manager.manager_service_points.create!(service_point_id: service_point_id)
          end
        end
        
        render json: @manager.as_json(include: { 
          user: { only: [:id, :email, :phone, :first_name, :last_name] },
          service_points: { only: [:id, :name] }
        }), status: :created
        
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors }, status: :unprocessable_entity
      end
      
      # PATCH/PUT /api/v1/partners/:partner_id/managers/:id
      def update
        ActiveRecord::Base.transaction do
          # Обновляем данные пользователя, если они переданы
          if params[:user].present? && @manager.user
            user_params = params.require(:user).permit(:email, :phone, :first_name, :last_name, :middle_name)
            @manager.user.update!(user_params)
          end
          
          # Обновляем данные менеджера
          @manager.update!(manager_params)
          
          # Обновляем связанные сервисные точки, если они указаны
          if params[:service_point_ids].present?
            service_point_ids = params[:service_point_ids].is_a?(Array) ? params[:service_point_ids] : params[:service_point_ids].split(',')
            
            # Проверяем, что все ID принадлежат партнеру
            service_point_ids.each do |service_point_id|
              unless @partner.service_points.exists?(id: service_point_id)
                raise ActiveRecord::RecordNotFound, "Service point #{service_point_id} not found or does not belong to this partner"
              end
            end
            
            # Удаляем старые связи и создаем новые
            @manager.manager_service_points.destroy_all
            service_point_ids.each do |service_point_id|
              @manager.manager_service_points.create!(service_point_id: service_point_id)
            end
          end
        end
        
        render json: @manager.as_json(include: { 
          user: { only: [:id, :email, :phone, :first_name, :last_name] },
          service_points: { only: [:id, :name] }
        })
        
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors }, status: :unprocessable_entity
      rescue ActiveRecord::RecordNotFound => e
        render json: { error: e.message }, status: :not_found
      end
      
      # DELETE /api/v1/partners/:partner_id/managers/:id
      def destroy
        if @manager.user.update(is_active: false)
          head :no_content
        else
          render json: { errors: @manager.user.errors }, status: :unprocessable_entity
        end
      end
      
      private
      
      def set_manager
        @manager = Manager.find(params[:id])
        @partner = @manager.partner
      end
      
      def set_partner
        @partner = Partner.find(params[:partner_id])
      end
      
      def manager_params
        params.require(:manager).permit(:position, :access_level)
      end
      
      def authorize_admin
        unless current_user && current_user.admin?
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end
    end
  end
end 