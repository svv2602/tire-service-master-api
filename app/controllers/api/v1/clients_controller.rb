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
        
        # Поиск по данным пользователя (email, имени, фамилии или номеру телефона)
        if params[:query].present?
          @clients = @clients.joins(:user).where(
            "users.email LIKE ? OR users.first_name LIKE ? OR users.last_name LIKE ? OR users.phone LIKE ?", 
            "%#{params[:query]}%", "%#{params[:query]}%", "%#{params[:query]}%", "%#{params[:query]}%"
          )
        end
        
        # Фильтрация по активности
        if params[:active].present?
          @clients = @clients.joins(:user).where(users: { is_active: params[:active] == 'true' })
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
        
        begin
          ActiveRecord::Base.transaction do
            puts "🔍 CLIENT CREATE DEBUG:"
            puts "  User params: #{client_user_params.inspect}"
            puts "  Client params: #{client_params.inspect}"
            
            @user = User.new(client_user_params)
            @user.role = UserRole.find_by(name: 'client')
            @user.save!
            
            # Клиент уже создан через коллбэк в модели User
            @client = @user.client
            
            # Если есть параметры client, обновляем существующий клиент
            if params[:client].present?
              puts "  Updating client with: #{client_params.inspect}"
              unless @client.update(client_params)
                puts "  ❌ Client update failed: #{@client.errors.full_messages}"
                raise ActiveRecord::RecordInvalid.new(@client)
              end
            end
            
            puts "  ✅ Client created successfully: ID=#{@client.id}"
          end
          
          render json: @client, status: :created
        rescue ActiveRecord::RecordInvalid => e
          puts "  ❌ Validation error: #{e.record.errors.full_messages}"
          render json: { errors: e.record.errors }, status: :unprocessable_entity
        rescue => e
          puts "  ❌ General error: #{e.message}"
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/clients/register
      # POST /api/v1/register
      def register
        begin
          ActiveRecord::Base.transaction do
            client_role = UserRole.find_by(name: 'client')
            
            user = User.new(
              email: register_params[:email],
              password: register_params[:password],
              password_confirmation: register_params[:password_confirmation],
              first_name: register_params[:first_name],
              last_name: register_params[:last_name],
              phone: register_params[:phone],
              role: client_role
            )

            if user.save
              client = Client.create!(user: user)
              token = Auth::JsonWebToken.encode_access_token(user_id: user.id)
              
              render json: {
                message: 'Регистрация прошла успешно',
                auth_token: token,
                user: user.as_json(only: [:id, :email, :first_name, :last_name, :phone]),
                client: client.as_json(only: [:id]),
                tokens: {
                  access: token,
                  refresh: token # В данной реализации используем тот же токен для refresh
                }
              }, status: :created
            else
              render json: { 
                message: 'Failed to create account',
                errors: user.errors.full_messages 
              }, status: :unprocessable_entity
            end
          end
        rescue ActiveRecord::RecordInvalid => e
          render json: { 
            message: 'Failed to create account',
            errors: e.record.errors.full_messages 
          }, status: :unprocessable_entity
        rescue StandardError => e
          render json: { 
            error: 'Internal server error',
            message: e.message 
          }, status: :internal_server_error
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
        
        puts "🔍 CLIENT UPDATE DEBUG:"
        puts "  Current user: #{current_user&.email} (role: #{current_user&.role&.name})"
        puts "  Client ID: #{@client.id}"
        puts "  Client user ID: #{@client.user_id}"
        puts "  Received params: #{params.inspect}"
        puts "  User update params: #{client_user_update_params.inspect}"
        puts "  Client update params: #{client_update_params.inspect}"
        
        old_values = @client.as_json
        
        Client.transaction do
          if client_user_update_params.present?
            puts "  Updating user with: #{client_user_update_params.inspect}"
            @client.user.update!(client_user_update_params)
          end
          
          if client_update_params.present?
            puts "  Updating client with: #{client_update_params.inspect}"
            @client.update!(client_update_params)
          end
        end
        
        puts "  ✅ Update successful"
        log_action('update', 'client', @client.id, old_values, @client.as_json)
        render json: @client, status: :ok
        
      rescue ActiveRecord::RecordInvalid => e
        puts "  ❌ Validation error: #{e.record.errors.full_messages}"
        render json: { errors: e.record.errors }, status: :unprocessable_entity
      rescue => e
        puts "  ❌ General error: #{e.message}"
        render json: { error: e.message }, status: :internal_server_error
      end
      
      # DELETE /api/v1/clients/:id
      def destroy
        authorize @client
        
        puts "🔍 CLIENT DELETE DEBUG:"
        puts "  Current user: #{current_user&.email} (role: #{current_user&.role&.name})"
        puts "  Client ID: #{@client.id}"
        puts "  Client user ID: #{@client.user_id}"
        puts "  Client user active: #{@client.user.is_active}"
        
        old_values = @client.as_json
        
        if @client.user.update(is_active: false)
          puts "  ✅ Client deactivated successfully"
          log_action('deactivate', 'client', @client.id, old_values, @client.as_json)
          render json: { message: 'Client deactivated successfully' }
        else
          puts "  ❌ Failed to deactivate client: #{@client.user.errors.full_messages}"
          render json: { errors: @client.user.errors }, status: :unprocessable_entity
        end
      rescue => e
        puts "  ❌ General error in delete: #{e.message}"
        render json: { error: e.message }, status: :internal_server_error
      end
      
      private
      
      def set_client
        @client = Client.includes(:user).find(params[:id])
      end
      
      def client_user_params
        params.require(:user).permit(:email, :phone, :password, :password_confirmation, :first_name, :last_name, :middle_name)
      end
      
      def client_user_update_params
        params.fetch(:user, {}).permit(:email, :phone, :password, :password_confirmation, :first_name, :last_name, :middle_name, :is_active)
      end
      
      def client_params
        # Разрешаем параметры client для создания клиента
        params.fetch(:client, {}).permit(
          :preferred_notification_method,
          :marketing_consent
        )
      end
      
      def client_update_params
        params.fetch(:client, {}).permit(:preferred_notification_method, :marketing_consent)
      end
      
      def register_params
        params.require(:user).permit(:email, :password, :password_confirmation, :first_name, :last_name, :phone)
      end
    end
  end
end
