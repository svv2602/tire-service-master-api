module Api
  module V1
    class UsersController < ApiController
      before_action :set_user, only: [:show, :update, :destroy, :suspend, :unsuspend, :suspension_info]
      before_action :authorize_admin, except: [:show, :update, :me, :check_exists]
      skip_before_action :authenticate_request, only: [:check_exists]
      
      # GET /api/v1/users/me
      def me
        render json: current_user
      end
      
      # GET /api/v1/users
      def index
        # Генерируем ключ кэша на основе параметров запроса
        cache_key = generate_users_cache_key
        
        # Кэшируем результат для часто запрашиваемых данных
        cached_result = Rails.cache.fetch(cache_key, expires_in: RolesCacheConfig::USER_PERMISSIONS_TTL) do
          build_users_response
        end
        
        render json: cached_result
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
          render json: { 
            data: @user,
            message: I18n.t('users.messages.created')
          }, status: :created
        else
          render json: { 
            error: I18n.t('users.errors.create_failed'),
            details: @user.errors 
          }, status: :unprocessable_entity
        end
      end
      
      # PUT /api/v1/users/:id
      def update
        authorize @user
        
        puts "🔍 USER UPDATE DEBUG:"
        puts "  User ID: #{@user.id}"
        puts "  Current user data: #{@user.attributes.inspect}"
        puts "  Received params: #{params.inspect}"
        puts "  User update params: #{user_update_params.inspect}"
        
        old_values = @user.as_json
        
        if @user.update(user_update_params)
          puts "  ✅ Update successful"
          begin
            log_action('update', 'user', @user.id, old_values, @user.as_json)
          rescue => e
            puts "  ⚠️ Audit logging failed: #{e.message}"
            # Продолжаем выполнение, даже если аудит не сработал
          end
          render json: { 
            data: @user,
            message: I18n.t('users.messages.updated')
          }
        else
          puts "  ❌ Update failed with errors: #{@user.errors.full_messages}"
          puts "  ❌ Detailed errors: #{@user.errors.details}"
          render json: { 
            error: I18n.t('users.errors.update_failed'),
            details: @user.errors.full_messages
          }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/users/:id
      def destroy
        authorize @user
        
        old_values = @user.as_json
        
        if @user.update(is_active: false)
          log_action('deactivate', 'user', @user.id, old_values, @user.as_json)
          render json: { message: I18n.t('users.messages.deactivated') }
        else
          render json: { 
            error: I18n.t('users.errors.deactivate_failed'),
            details: @user.errors 
          }, status: :unprocessable_entity
        end
      end
      
      # PATCH /api/v1/users/:id/suspend
      # Заблокировать пользователя
      def suspend
        authorize @user, :suspend?
        
        reason = params[:reason] || 'Причина не указана'
        until_date = params[:until_date].present? ? Time.parse(params[:until_date]) : nil
        
        begin
          @user.suspend!(
            reason: reason,
            until_date: until_date,
            suspended_by_user: current_user
          )
          
          # Логируем блокировку
          AuditLogJob.log_suspend(
            user_id: current_user.id,
            target_user_id: @user.id,
            reason: reason,
            until_date: until_date,
            ip_address: request.remote_ip,
            user_agent: request.user_agent
          )
          
          # Отправляем уведомление пользователю
          send_suspension_notification(@user, reason, until_date)
          
          render json: {
            data: build_suspension_info(@user),
            message: 'Пользователь успешно заблокирован'
          }
        rescue => e
          render json: {
            error: 'Ошибка при блокировке пользователя',
            details: e.message
          }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/users/:id/unsuspend
      # Разблокировать пользователя
      def unsuspend
        authorize @user, :unsuspend?
        
        begin
          @user.unsuspend!(unsuspended_by_user: current_user)
          
          # Логируем разблокировку
          AuditLogJob.log_unsuspend(
            user_id: current_user.id,
            target_user_id: @user.id,
            ip_address: request.remote_ip,
            user_agent: request.user_agent
          )
          
          # Отправляем уведомление о разблокировке
          send_unsuspension_notification(@user)
          
          render json: {
            data: build_suspension_info(@user),
            message: 'Пользователь успешно разблокирован'
          }
        rescue => e
          render json: {
            error: 'Ошибка при разблокировке пользователя',
            details: e.message
          }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/users/:id/suspension_info
      # Получить информацию о блокировке пользователя
      def suspension_info
        authorize @user, :show?
        
        render json: {
          data: build_suspension_info(@user)
        }
      end

      # Проверка существования пользователя по телефону или email
      def check_exists
        phone = params[:phone]
        email = params[:email]
        
        if phone.blank? && email.blank?
          render json: { error: I18n.t('users.errors.contact_info_required') }, status: :bad_request
          return
        end
        
        user = nil
        
        # Поиск по телефону
        if phone.present?
          normalized_phone = phone.gsub(/[^\d+]/, '')
          user = User.find_by(phone: normalized_phone)
        end
        
        # Поиск по email, если не найден по телефону
        if user.nil? && email.present?
          user = User.find_by(email: email.downcase)
        end
        
        if user
          render json: {
            exists: true,
            user: {
              id: user.id,
              first_name: user.first_name,
              last_name: user.last_name,
              email: user.email,
              phone: user.phone,
              role: user.role.name,
              client_id: user.client&.id
            }
          }
        else
          render json: { exists: false }
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

      # Получить информацию о блокировке пользователя
      def build_suspension_info(user)
        if user.suspended?
          {
            is_suspended: true,
            reason: user.suspension_reason,
            suspended_at: user.suspended_at&.iso8601,
            suspended_until: user.suspended_until&.iso8601,
            suspended_by: user.suspended_by&.full_name,
            is_permanent: user.suspended_until.blank?,
            days_remaining: user.suspended_until.present? ? 
              [(user.suspended_until.to_date - Date.current).to_i, 0].max : nil
          }
        else
          {
            is_suspended: false,
            reason: nil,
            suspended_at: nil,
            suspended_until: nil,
            suspended_by: nil,
            is_permanent: false,
            days_remaining: nil
          }
        end
      end

      # Отправить уведомление о блокировке
      def send_suspension_notification(user, reason, until_date)
        return unless user.email.present?
        
        begin
          # Используем существующую систему email уведомлений
          template_data = {
            user_name: user.full_name,
            reason: reason,
            suspended_until: until_date&.strftime('%d.%m.%Y %H:%M'),
            is_permanent: until_date.blank?,
            support_email: 'support@tireservice.com'
          }
          
          # Отправляем email через систему уведомлений
          # EmailNotificationService.send_template(
          #   user.email,
          #   'user_suspended',
          #   template_data
          # )
          
          Rails.logger.info "Отправлено уведомление о блокировке пользователю #{user.email}"
        rescue => e
          Rails.logger.error "Ошибка отправки уведомления о блокировке: #{e.message}"
        end
      end

      # Отправить уведомление о разблокировке
      def send_unsuspension_notification(user)
        return unless user.email.present?
        
        begin
          template_data = {
            user_name: user.full_name,
            unsuspended_at: Time.current.strftime('%d.%m.%Y %H:%M'),
            support_email: 'support@tireservice.com'
          }
          
          # EmailNotificationService.send_template(
          #   user.email,
          #   'user_unsuspended',
          #   template_data
          # )
          
          Rails.logger.info "Отправлено уведомление о разблокировке пользователю #{user.email}"
        rescue => e
          Rails.logger.error "Ошибка отправки уведомления о разблокировке: #{e.message}"
        end
      end

      def generate_users_cache_key
        # Создаем уникальный ключ кэша на основе всех параметров запроса
        key_parts = [
          'users',
          params[:role],
          params[:active],
          params[:is_suspended],
          params[:query],
          params[:page],
          params[:per_page],
          current_user&.id,
          current_user&.role
        ].compact.join('/')
        
        # Добавляем timestamp последнего обновления пользователей
        last_updated = User.maximum(:updated_at)&.to_i || 0
        "#{key_parts}/#{last_updated}"
      end

      def build_users_response
        @users = User.includes(:role, :suspended_by).all
        
        # Фильтрация по роли
        @users = @users.with_role(params[:role]) if params[:role].present?
        
        # Фильтрация по активности
        if params[:active].present?
          @users = @users.where(is_active: params[:active] == 'true')
        end
        
        # Фильтрация по статусу блокировки
        if params[:is_suspended].present?
          @users = @users.where(is_suspended: params[:is_suspended] == 'true')
        end
        
        # Поиск по email, имени или номеру телефона
        if params[:query].present?
          query_downcase = params[:query].downcase
          @users = @users.where("LOWER(email) LIKE ? OR LOWER(first_name) LIKE ? OR LOWER(last_name) LIKE ? OR phone LIKE ?", 
                               "%#{query_downcase}%", "%#{query_downcase}%", "%#{query_downcase}%", "%#{params[:query]}%")
        end
        
        paginate(@users.order(created_at: :desc))
      end
    end
  end
end
