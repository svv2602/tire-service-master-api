module Api
  module V1
    class PartnersController < ApiController
      before_action :set_partner, only: [:show, :update, :destroy]
      before_action :authorize_admin, except: [:index, :show, :create_test]
      skip_before_action :authenticate_request, only: [:index, :create_test]
      
      # GET /api/v1/partners
      def index
        @partners = Partner.includes(:user).all
        
        # Поиск по имени компании или контактному лицу
        if params[:query].present?
          @partners = @partners.where("company_name LIKE ? OR contact_person LIKE ?", 
                               "%#{params[:query]}%", "%#{params[:query]}%")
        end
        
        # Пагинация
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 10).to_i
        offset = (page - 1) * per_page
        
        total_count = @partners.count
        @partners = @partners.offset(offset).limit(per_page)
        
        # Если нет партнеров, возвращаем пустой массив для тестирования
        if @partners.empty?
          render json: {
            partners: [],
            total_items: 0
          }
          return
        end
        
        render json: {
          partners: @partners.as_json(include: { user: { only: [:id, :email, :phone, :first_name, :last_name] } }),
          total_items: total_count
        }
      end
      
      # GET /api/v1/partners/:id
      def show
        render json: @partner.as_json(include: { user: { only: [:id, :email, :phone, :first_name, :last_name] } })
      end
      
      # POST /api/v1/partners
      def create
        ActiveRecord::Base.transaction do
          # Сначала создаем пользователя, если user_id не указан
          if params[:user_id].blank? && params[:user].present?
            user_params = params.require(:user).permit(:email, :password, :phone, :first_name, :last_name, :middle_name)
            @user = User.new(user_params)
            @user.role = UserRole.find_by(name: 'operator')
            @user.save!
            
            user_id = @user.id
          else
            user_id = params[:user_id]
          end
          
          # Затем создаем партнера
          @partner = Partner.new(partner_params)
          @partner.user_id = user_id
          @partner.save!
        end
        
        render json: @partner.as_json(include: { user: { only: [:id, :email, :phone, :first_name, :last_name] } }), status: :created
        
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors }, status: :unprocessable_entity
      end
      
      # POST /api/v1/partners/create_test
      def create_test
        ActiveRecord::Base.transaction do
          # Создаем пользователя
          @user = User.create!(
            email: "partner_test_#{Time.now.to_i}@example.com",
            password: 'password',
            password_confirmation: 'password',
            first_name: 'Тест',
            last_name: 'Партнер',
            phone: "+38067#{Random.rand(1000000..9999999)}",
            role: UserRole.find_by(name: 'operator')
          )
          
          # Создаем партнера
          @partner = Partner.create!(
            user_id: @user.id,
            company_name: "Тестовая компания #{Time.now.to_i}",
            company_description: "Описание тестовой компании",
            contact_person: "Тест Партнер",
            logo_url: "https://via.placeholder.com/150",
            website: "http://test-company.com",
            tax_number: "12345678",
            legal_address: "ул. Тестовая, 123"
          )
        end
        
        render json: @partner.as_json(include: { user: { only: [:id, :email, :phone, :first_name, :last_name] } }), status: :created
        
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors }, status: :unprocessable_entity
      end
      
      # PUT /api/v1/partners/:id
      def update
        ActiveRecord::Base.transaction do
          # Обновляем данные пользователя, если они переданы
          if params[:user].present? && @partner.user
            user_params = params.require(:user).permit(:email, :phone, :first_name, :last_name, :middle_name)
            @partner.user.update!(user_params)
          end
          
          # Обновляем данные партнера
          @partner.update!(partner_params)
        end
        
        render json: @partner.as_json(include: { user: { only: [:id, :email, :phone, :first_name, :last_name] } })
        
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors }, status: :unprocessable_entity
      end
      
      # DELETE /api/v1/partners/:id
      def destroy
        @partner.destroy
        head :no_content
      end
      
      private
      
      def set_partner
        @partner = Partner.find(params[:id])
      end
      
      def partner_params
        params.require(:partner).permit(
          :company_name, :company_description, :contact_person, 
          :logo_url, :website, :tax_number, :legal_address
        )
      end
      
      def authorize_admin
        unless current_user && current_user.admin?
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end
    end
  end
end 