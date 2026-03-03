# Контроллер для восстановления пароля
module Api
  module V1
    class PasswordsController < BaseController
      skip_before_action :authenticate_request
      skip_after_action :verify_authorized
      
      # POST /api/v1/password/forgot
      # Запрос на восстановление пароля
      def forgot
        login = params[:login]
        
        # Security: log only non-sensitive info
        Rails.logger.debug "Password: reset requested"
        
        unless login.present?
          render json: { error: I18n.t('auth.errors.credentials_required') }, status: :unprocessable_entity
          return
        end
        
        # ✅ Поиск пользователя по email или телефону
        user = User.find_by_login(login)
        
        unless user
          # Для безопасности не раскрываем, что пользователь не найден
          render json: { message: I18n.t('auth.messages.password_reset_sent') }, status: :ok
          return
        end
        
        unless user.is_active?
          render json: { error: I18n.t('auth.errors.account_blocked') }, status: :forbidden
          return
        end
        
        # Генерируем токен восстановления
        reset_token = SecureRandom.urlsafe_base64(32)
        reset_expires_at = 2.hours.from_now
        
        Rails.logger.debug "Password: generated reset token for user_id=#{user.id}"
        
        # Сохраняем токен и время истечения
        if user.update(password_reset_token: reset_token, password_reset_sent_at: reset_expires_at)
          # Определяем способ отправки на основе того, что указал пользователь
          if user.email.present? && login.include?('@')
            # Отправляем email
            begin
              # Используем EmailTemplateMailer вместо PasswordResetMailer для единообразия
              EmailTemplateMailer.password_reset(user.id, reset_token).deliver_now
              Rails.logger.debug "Password: reset email sent for user_id=#{user.id}"
              render json: { message: I18n.t('auth.messages.password_reset_sent_email') }
            rescue => e
              Rails.logger.error "Failed to send password reset email: #{e.class.name}: #{e.message}"
              Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}"
              render json: { error: I18n.t('auth.errors.password_reset_email_failed') }, status: :internal_server_error
            end
          elsif user.phone.present?
            # Отправляем SMS
            begin
              result = SmsService.send_password_reset(user.phone, reset_token)
              if result[:success]
                Rails.logger.debug "Password: reset SMS sent for user_id=#{user.id}"
                render json: { message: I18n.t('auth.messages.password_reset_sent_sms') }
              else
                Rails.logger.error "Failed to send SMS: #{result[:error]}"
                render json: { error: result[:error] }, status: :internal_server_error
              end
            rescue => e
              Rails.logger.error "Failed to send password reset SMS: #{e.message}"
              render json: { error: I18n.t('auth.errors.password_reset_sms_failed') }, status: :internal_server_error
            end
          else
            render json: { error: I18n.t('auth.errors.contact_info_missing') }, status: :unprocessable_entity
          end
        else
          Rails.logger.error "Failed to save password reset token for user: #{user.id}"
          render json: { error: I18n.t('auth.errors.token_create_failed') }, status: :internal_server_error
        end
      end
      
      # POST /api/v1/password/reset
      # Сброс пароля по токену
      def reset
        token = params[:token]
        password = params[:password]
        password_confirmation = params[:password_confirmation]
        
        unless token.present? && password.present? && password_confirmation.present?
          render json: { error: I18n.t('auth.errors.reset_fields_required') }, status: :unprocessable_entity
          return
        end
        
        # Ищем пользователя по токену
        user = User.find_by(password_reset_token: token)
        
        unless user
          render json: { error: I18n.t('auth.errors.token_invalid') }, status: :unprocessable_entity
          return
        end
        
        # Проверяем, что токен не истёк
        unless user.password_reset_sent_at && user.password_reset_sent_at > Time.current
          render json: { error: I18n.t('auth.errors.token_expired') }, status: :unprocessable_entity
          return
        end
        
        # Проверяем совпадение паролей
        unless password == password_confirmation
          render json: { error: I18n.t('auth.errors.passwords_not_match') }, status: :unprocessable_entity
          return
        end
        
        # Обновляем пароль и очищаем токен
        if user.update(
          password: password,
          password_confirmation: password_confirmation,
          password_reset_token: nil,
          password_reset_sent_at: nil
        )
          # Revoke all existing tokens for this user after password change
          TokenBlacklistService.revoke_all_for_user(user.id)
          Rails.logger.info("Password successfully reset for user: #{user.id}")
          render json: { message: I18n.t('auth.messages.password_reset_success') }
        else
          render json: { 
            error: I18n.t('auth.errors.password_reset_failed'),
            details: user.errors.full_messages 
          }, status: :unprocessable_entity
        end
      end
      
      # GET /api/v1/password/verify_token/:token
      # Проверка действительности токена восстановления
      def verify_token
        token = params[:token]
        
        unless token.present?
          render json: { error: I18n.t('auth.errors.token_required') }, status: :unprocessable_entity
          return
        end
        
        user = User.find_by(password_reset_token: token)
        
        if user && user.password_reset_sent_at && user.password_reset_sent_at > Time.current
          render json: { 
            valid: true,
            expires_at: user.password_reset_sent_at,
            user: {
              email: user.email&.present? ? mask_email(user.email) : nil,
              phone: user.phone&.present? ? mask_phone(user.phone) : nil
            }
          }
        else
          render json: { 
            valid: false,
            error: I18n.t('auth.errors.token_invalid_or_expired')
          }
        end
      end
      
      private
      
      # Маскировка email для безопасности
      def mask_email(email)
        return email if email.blank?
        
        local, domain = email.split('@')
        if local.length <= 2
          "#{local[0]}***@#{domain}"
        else
          "#{local[0..1]}***@#{domain}"
        end
      end
      
      # Маскировка телефона для безопасности
      def mask_phone(phone)
        return phone if phone.blank?
        
        if phone.length <= 4
          "***#{phone[-2..-1]}"
        else
          "***#{phone[-4..-1]}"
        end
      end
    end
  end
end 