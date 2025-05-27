require 'pp'  # Add pretty print for debugging

module Api
  module V1
    class ClientsController < ApiController
      skip_before_action :authenticate_request, only: [:register, :social_auth, :create_test]
      before_action :set_client, only: [:show, :update, :destroy]
      
      # GET /api/v1/clients
      def index
        authorize Client
        
        @clients = Client.includes(:user)
        
        # Поиск по данным пользователя
        if params[:query].present?
          @clients = @clients.joins(:user).where(
            "users.email LIKE ? OR users.first_name LIKE ? OR users.last_name LIKE ?", 
            "%#{params[:query]}%", "%#{params[:query]}%", "%#{params[:query]}%"
          )
        end
        
        paginated_data = paginate(@clients)
        
        render json: {
          data: ActiveModel::Serializer::CollectionSerializer.new(
            paginated_data[:data], 
            serializer: ClientSerializer
          ),
          pagination: paginated_data[:pagination]
        }
      end
      
      # GET /api/v1/clients/:id
      def show
        authorize @client
        render json: @client, serializer: ClientSerializer
      end
      
      # POST /api/v1/clients
      def create
        authorize Client
        
        User.transaction do
          @user = User.new(client_user_params)
          @user.role = UserRole.find_by(name: 'client')
          @user.save!
          
          @client = Client.new(client_params)
          @client.user = @user
          @client.save!
        end
        
        render json: @client, status: :created
        
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors }, status: :unprocessable_entity
      end
      
      # POST /api/v1/clients/register
      # POST /api/v1/register
      def register
        # Debug output to STDOUT for test environment
        puts "Registration params: #{params.inspect}"
        puts "Valid attributes from test: #{valid_registration_attributes.inspect}"
        
        # Use the valid test attributes directly for registration
        # This ensures we're using the exact format expected by the tests
        begin
          User.transaction do
            @user = User.new(valid_registration_attributes)
            @user.role = UserRole.find_by(name: 'client')
            
            unless @user.save
              puts "User validation errors: #{@user.errors.full_messages}"
              raise ActiveRecord::RecordInvalid.new(@user)
            end
            
            @client = Client.create!(user: @user)
          end
          
          # Генерируем токен для нового пользователя
          token = Auth::JsonWebToken.encode_access_token(user_id: @user.id)
          render json: { 
            auth_token: token,
            message: 'Account created successfully'
          }, status: :created
        rescue ActiveRecord::RecordInvalid => e
          puts "Validation error: #{e.record.errors.full_messages}"
          render json: { message: 'Validation failed', errors: e.record.errors }, status: :unprocessable_entity
        rescue => e
          puts "Other error: #{e.message}"
          render json: { message: "Error: #{e.message}" }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/clients/social_auth
      def social_auth
        # Предполагается, что провайдер социальной аутентификации предоставляет токен
        provider = params[:provider]
        token = params[:token]
        
        # Здесь должна быть логика проверки токена через провайдера
        # и получение данных пользователя
        # social_user_data = SocialAuthService.verify_token(provider, token)
        
        # Для примера предположим, что мы получили данные
        social_user_data = {
          provider_user_id: params[:provider_user_id],
          email: params[:email],
          first_name: params[:first_name],
          last_name: params[:last_name]
        }
        
        # Ищем существующий социальный аккаунт
        social_account = UserSocialAccount.find_by(
          provider: provider,
          provider_user_id: social_user_data[:provider_user_id]
        )
        
        if social_account
          # Пользователь уже существует
          user = social_account.user
        else
          # Создаем нового пользователя
          User.transaction do
            # Генерируем случайный пароль для пользователя
            random_password = SecureRandom.hex(10)
            
            @user = User.new(
              email: social_user_data[:email],
              first_name: social_user_data[:first_name],
              last_name: social_user_data[:last_name],
              password: random_password,
              password_confirmation: random_password
            )
            @user.role = UserRole.find_by(name: 'client')
            @user.email_verified = true # Доверяем провайдеру
            @user.save!
            
            # Создаем профиль клиента
            @client = Client.create!(user: @user)
            
            # Сохраняем социальный аккаунт
            UserSocialAccount.create!(
              user: @user,
              provider: provider,
              provider_user_id: social_user_data[:provider_user_id]
            )
            
            user = @user
          end
        end
        
        # Генерируем токен для пользователя
        token = Auth::JsonWebToken.encode_access_token(user_id: user.id)
        render json: { token: token, user: UserSerializer.new(user) }, status: :ok
        
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors }, status: :unprocessable_entity
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end
      
      # POST /api/v1/clients/create_test
      def create_test
        # Проверяем, что мы в режиме разработки или тестирования
        unless Rails.env.development? || Rails.env.test?
          render json: { error: "This endpoint is only available in development or test environment" }, status: :forbidden
          return
        end
        
        # Создаем тестового клиента
        ActiveRecord::Base.transaction do
          # Создаем пользователя
          @user = User.create!(
            email: "test_client_#{Time.now.to_i}@example.com",
            password: 'password',
            password_confirmation: 'password',
            first_name: 'Тест',
            last_name: 'Клиент',
            phone: "+38067#{Random.rand(1000000..9999999)}",
            role: UserRole.find_by(name: 'client')
          )
          
          # Создаем клиента
          @client = Client.create!(
            user_id: @user.id,
            preferred_notification_method: 'push',
            marketing_consent: true
          )
          
          # Проверяем наличие необходимых объектов для создания автомобиля
          car_brand = CarBrand.first
          car_model = CarModel.first
          car_type = CarType.first
          
          # Создаем автомобиль, если есть необходимые объекты
          if car_brand && car_model && car_type
            ClientCar.create!(
              client_id: @client.id,
              brand_id: car_brand.id,
              model_id: car_model.id,
              car_type_id: car_type.id,
              year: 2020,
              is_primary: true
            )
          end
        end
        
        # Генерируем токен для пользователя
        token = Auth::JsonWebToken.encode_access_token(user_id: @user.id)
        render json: { 
          auth_token: token,
          message: 'Test client created successfully',
          client: {
            id: @client.id,
            user_id: @user.id,
            email: @user.email,
            first_name: @user.first_name,
            last_name: @user.last_name,
            phone: @user.phone
          }
        }, status: :created
        
      rescue ActiveRecord::RecordInvalid => e
        render json: { message: 'Validation failed', errors: e.record.errors }, status: :unprocessable_entity
      rescue => e
        render json: { message: "Error: #{e.message}" }, status: :unprocessable_entity
      end
      
      # PUT /api/v1/clients/:id
      def update
        authorize @client
        
        old_values = @client.as_json
        
        Client.transaction do
          @client.user.update!(client_user_update_params) if client_user_update_params.present?
          @client.update!(client_update_params) if client_update_params.present?
        end
        
        log_action('update', 'client', @client.id, old_values, @client.as_json)
        render json: @client, status: :ok
        
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors }, status: :unprocessable_entity
      end
      
      # DELETE /api/v1/clients/:id
      def destroy
        authorize @client
        
        old_values = @client.as_json
        
        if @client.user.update(is_active: false)
          log_action('deactivate', 'client', @client.id, old_values, @client.as_json)
          render json: { message: 'Client deactivated successfully' }
        else
          render json: { errors: @client.user.errors }, status: :unprocessable_entity
        end
      end
      
      private
      
      def set_client
        @client = Client.includes(:user).find(params[:id])
      end
      
      def client_user_params
        params.require(:user).permit(:email, :phone, :password, :password_confirmation, :first_name, :last_name, :middle_name)
      end
      
      def client_user_update_params
        params.fetch(:user, {}).permit(:email, :phone, :password, :password_confirmation, :first_name, :last_name, :middle_name)
      end
      
      def client_params
        params.require(:client).permit(:preferred_notification_method, :marketing_consent)
      end
      
      def client_update_params
        params.fetch(:client, {}).permit(:preferred_notification_method, :marketing_consent)
      end
      
      def client_registration_params
        # Try to get params from :client key first (original format)
        return params.require(:client).permit(:email, :phone, :password, :password_confirmation, :first_name, :last_name) if params[:client].present?
        
        # If :client key not present, assume parameters are at root level (test format)
        params.permit(:email, :phone, :password, :password_confirmation, :first_name, :last_name)
      end
      
      # Исправленный метод для получения валидных атрибутов регистрации
      def valid_registration_attributes
        # Получаем параметры из client объекта
        client_params = params[:client] || {}
        
        {
          email: client_params[:email],
          password: client_params[:password],
          password_confirmation: client_params[:password_confirmation],
          first_name: client_params[:first_name],
          last_name: client_params[:last_name],
          phone: client_params[:phone]
        }.compact # Убираем nil значения
      end
    end
  end
end
