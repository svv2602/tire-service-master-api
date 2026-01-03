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
          
          render json: {
            data: @client,
            message: I18n.t('clients.messages.created')
          }, status: :created
        rescue ActiveRecord::RecordInvalid => e
          puts "  ❌ Validation error: #{e.record.errors.full_messages}"
          render json: { 
            error: I18n.t('clients.errors.create_failed'),
            details: e.record.errors 
          }, status: :unprocessable_entity
        rescue => e
          puts "  ❌ General error: #{e.message}"
          render json: { error: I18n.t('errors.internal') }, status: :unprocessable_entity
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
                message: I18n.t('auth.messages.registration_success'),
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
                error: I18n.t('auth.errors.registration_failed'),
                details: user.errors.full_messages 
              }, status: :unprocessable_entity
            end
          end
        rescue ActiveRecord::RecordInvalid => e
          render json: { 
            error: I18n.t('auth.errors.registration_failed'),
            details: e.record.errors.full_messages 
          }, status: :unprocessable_entity
        rescue StandardError => e
          render json: { 
            error: I18n.t('errors.internal'),
            details: e.message 
          }, status: :internal_server_error
        end
      end
      
      # POST /api/v1/clients/social_auth
      def social_auth
        Rails.logger.info "🔐 Social auth request: #{params.inspect}"
        
        provider = params[:provider]
        token = params[:token]
        provider_user_id = params[:provider_user_id]
        email = params[:email]
        
        # ✅ ИСПРАВЛЕНИЕ: Обеспечиваем корректную UTF-8 кодировку для имен
        first_name = params[:first_name]
        last_name = params[:last_name]
        
        # Принудительно устанавливаем UTF-8 кодировку и проверяем валидность
        if first_name.present?
          first_name = first_name.to_s.force_encoding('UTF-8')
          unless first_name.valid_encoding?
            Rails.logger.warn "⚠️ Некорректная кодировка first_name, пытаемся исправить"
            first_name = first_name.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
          end
        end
        
        if last_name.present?
          last_name = last_name.to_s.force_encoding('UTF-8')
          unless last_name.valid_encoding?
            Rails.logger.warn "⚠️ Некорректная кодировка last_name, пытаемся исправить"
            last_name = last_name.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
          end
        end
        
        Rails.logger.info "🔧 После обработки UTF-8: first_name='#{first_name}', last_name='#{last_name}'"
        
        # Проверяем обязательные поля
        unless provider.present? && token.present? && provider_user_id.present? && email.present?
          render json: {
            error: 'Недостаточно данных для авторизации',
            details: 'Обязательные поля: provider, token, provider_user_id, email'
          }, status: :unprocessable_entity
          return
        end

        # Verify Google token for security (if Google provider)
        if provider == 'google' && ENV['GOOGLE_CLIENT_ID'].present?
          begin
            verified_info = GoogleOAuthService.verify(token)
            Rails.logger.info "✅ Google token verified for: #{verified_info[:email]}"

            # Use verified data from Google instead of client-provided data
            provider_user_id = verified_info[:provider_user_id]
            email = verified_info[:email]
            first_name = verified_info[:first_name] if verified_info[:first_name].present?
            last_name = verified_info[:last_name] if verified_info[:last_name].present?
          rescue GoogleOAuthService::TokenVerificationError => e
            Rails.logger.warn "⚠️ Google token verification failed: #{e.message}"
            render json: {
              error: 'Ошибка верификации токена Google',
              details: e.message
            }, status: :unauthorized
            return
          end
        end

        begin
          User.transaction do
            user = nil
            
            # 1. Ищем существующий социальный аккаунт
            if defined?(UserSocialAccount)
              social_account = UserSocialAccount.find_by(
                provider: provider,
                provider_user_id: provider_user_id
              )
              
              if social_account
                Rails.logger.info "✅ Найден существующий социальный аккаунт для пользователя ID: #{social_account.user_id}"
                user = social_account.user
              end
            end
            
            # 2. Если социального аккаунта нет, ищем пользователя по email
            if user.nil?
              user = User.find_by(email: email)
              
              if user
                Rails.logger.info "✅ Найден существующий пользователь по email: #{user.id}"
                # Привязываем социальный аккаунт к существующему пользователю
                if defined?(UserSocialAccount)
                  UserSocialAccount.create!(
                    user: user,
                    provider: provider,
                    provider_user_id: provider_user_id
                  )
                  Rails.logger.info "✅ Привязан социальный аккаунт к существующему пользователю"
                end
              end
            end
            
            # 3. Если пользователя совсем нет, создаем нового
            if user.nil?
              Rails.logger.info "🆕 Создаем нового пользователя для социальной авторизации"
              
              # Генерируем случайный пароль
              random_password = SecureRandom.hex(10)
              
              user = User.new(
                email: email,
                first_name: first_name || '',
                last_name: last_name || '',
                password: random_password,
                password_confirmation: random_password,
                email_verified: true, # Доверяем социальному провайдеру
                role: UserRole.find_by(name: 'client')
              )
              
              user.save!
              Rails.logger.info "✅ Создан новый пользователь ID: #{user.id} с именем '#{user.first_name} #{user.last_name}'"
              
              # Создаем профиль клиента (может быть создан автоматически через callback)
              unless user.client
                Client.create!(user: user, preferred_notification_method: 'email')
                Rails.logger.info "✅ Создан профиль клиента"
              end
              
              # Сохраняем социальный аккаунт
              if defined?(UserSocialAccount)
                UserSocialAccount.create!(
                  user: user,
                  provider: provider,
                  provider_user_id: provider_user_id
                )
                Rails.logger.info "✅ Создан социальный аккаунт"
              end
            end
            
            # 4. Генерируем токены и устанавливаем cookies
            access_token = Auth::JsonWebToken.encode_access_token(user_id: user.id)
            refresh_token = Auth::JsonWebToken.encode_refresh_token(user_id: user.id)
            
            Rails.logger.info "🔑 Генерируем токены для пользователя ID: #{user.id}"
            
            # ✅ Очищаем старые куки перед установкой новых
            cookies.delete(:access_token)
            cookies.delete(:refresh_token)
            
            # Устанавливаем cookies
            cookies[:access_token] = {
              value: access_token,
              httponly: true,
              secure: Rails.env.production?,
              same_site: :lax,
              expires: 1.hour.from_now,
              path: '/'
            }
            
            cookies[:refresh_token] = {
              value: refresh_token,
              httponly: true,
              secure: Rails.env.production?,
              same_site: :lax,
              expires: 30.days.from_now,
              path: '/'
            }
            
            Rails.logger.info "🍪 Cookies установлены"
            
            # 5. Возвращаем ответ в формате, ожидаемом фронтендом
            # ✅ ИСПРАВЛЕНИЕ: Убеждаемся, что JSON ответ содержит корректную UTF-8
            response_data = {
              auth_token: access_token,
              token: access_token, # Дублируем для совместимости
              user: {
                id: user.id,
                email: user.email,
                first_name: user.first_name.to_s.force_encoding('UTF-8'),
                last_name: user.last_name.to_s.force_encoding('UTF-8'),
                phone: user.phone,
                email_verified: user.email_verified,
                phone_verified: user.phone_verified,
                role: user.role.name,
                is_active: user.is_active?,
                client_id: user.client&.id,
                created_at: user.created_at,
                updated_at: user.updated_at
              },
              message: I18n.t('auth.messages.social_auth_success', default: 'Авторизация прошла успешно')
            }
            
            Rails.logger.info "✅ Social auth успешна для пользователя ID: #{user.id}, имя: '#{response_data[:user][:first_name]} #{response_data[:user][:last_name]}'"
            
            # Устанавливаем правильные заголовки для UTF-8
            response.headers['Content-Type'] = 'application/json; charset=utf-8'
            
            render json: response_data, status: :ok
          end
          
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "❌ Ошибка валидации при социальной авторизации: #{e.record.errors.full_messages}"
          render json: { 
            error: I18n.t('auth.errors.social_auth_failed', default: 'Ошибка социальной авторизации'),
            details: e.record.errors.full_messages
          }, status: :unprocessable_entity
        rescue => e
          Rails.logger.error "❌ Общая ошибка при социальной авторизации: #{e.message}"
          render json: { 
            error: I18n.t('errors.internal', default: 'Внутренняя ошибка сервера'),
            details: e.message
          }, status: :internal_server_error
        end
      end
      
      # POST /api/v1/clients/create_test
      def create_test
        # Проверяем, что мы в режиме разработки или тестирования
        unless Rails.env.development? || Rails.env.test?
          render json: { error: I18n.t('errors.test_mode_only') }, status: :forbidden
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
          message: I18n.t('clients.messages.test_created'),
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
        render json: { 
          error: I18n.t('clients.errors.test_create_failed'),
          details: e.record.errors 
        }, status: :unprocessable_entity
      rescue => e
        render json: { 
          error: I18n.t('errors.internal'),
          details: e.message 
        }, status: :unprocessable_entity
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
        render json: {
          data: @client,
          message: I18n.t('clients.messages.updated')
        }, status: :ok
        
      rescue ActiveRecord::RecordInvalid => e
        puts "  ❌ Validation error: #{e.record.errors.full_messages}"
        render json: { 
          error: I18n.t('clients.errors.update_failed'),
          details: e.record.errors 
        }, status: :unprocessable_entity
      rescue => e
        puts "  ❌ General error: #{e.message}"
        render json: { error: I18n.t('errors.internal') }, status: :internal_server_error
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
          render json: { message: I18n.t('clients.messages.deactivated') }
        else
          puts "  ❌ Failed to deactivate client: #{@client.user.errors.full_messages}"
          render json: { 
            error: I18n.t('clients.errors.deactivate_failed'),
            details: @client.user.errors 
          }, status: :unprocessable_entity
        end
      rescue => e
        puts "  ❌ General error in delete: #{e.message}"
        render json: { error: I18n.t('errors.internal') }, status: :internal_server_error
      end
      
      private
      
      def set_client
        @client = Client.includes(:user).find(params[:id])
      end
      
      def client_user_params
        user_params = params.require(:user).permit(:email, :phone, :password, :password_confirmation, :first_name, :last_name, :middle_name)
        
        # Преобразуем пустую строку email в nil для избежания конфликта уникальности
        user_params[:email] = nil if user_params[:email].present? && user_params[:email].strip.empty?
        
        user_params
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
