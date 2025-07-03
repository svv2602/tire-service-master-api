# Контроллер для восстановления пароля
module Api
  module V1
    class PasswordsController < BaseController
      skip_before_action :authenticate_request
      
      # POST /api/v1/password/forgot
      # Запрос на восстановление пароля
      def forgot
        login = params[:login]
        
        unless login.present?
          render json: { error: 'Необходимо указать email или номер телефона' }, status: :unprocessable_entity
          return
        end
        
        # ✅ Поиск пользователя по email или телефону
        user = User.find_by_login(login)
        
        unless user
          # Для безопасности не раскрываем, что пользователь не найден
          render json: { message: 'Если пользователь существует, инструкции будут отправлены' }, status: :ok
          return
        end
        
        unless user.is_active?
          render json: { error: 'Аккаунт заблокирован' }, status: :forbidden
          return
        end
        
        # Генерируем токен восстановления
        reset_token = SecureRandom.urlsafe_base64(32)
        reset_expires_at = 2.hours.from_now
        
        # Сохраняем токен и время истечения
        if user.update(password_reset_token: reset_token, password_reset_sent_at: reset_expires_at)
                   # Определяем способ отправки на основе того, что указал пользователь
         if user.email.present? && login.include?('@')
           # Отправляем email
           begin
             PasswordResetMailer.reset_instructions(user, reset_token).deliver_now
             Rails.logger.info("Password reset email sent to: #{user.email}")
             render json: { message: 'Инструкции по восстановлению отправлены на email' }
           rescue => e
             Rails.logger.error "Failed to send password reset email: #{e.message}"
             render json: { error: 'Не удалось отправить email' }, status: :internal_server_error
           end
         elsif user.phone.present?
           # Отправляем SMS
           begin
             result = SmsService.send_password_reset(user.phone, reset_token)
             if result[:success]
               Rails.logger.info("Password reset SMS sent to: #{user.phone}")
               render json: { message: 'Код восстановления отправлен на телефон' }
             else
               Rails.logger.error "Failed to send SMS: #{result[:error]}"
               render json: { error: result[:error] }, status: :internal_server_error
             end
           rescue => e
             Rails.logger.error "Failed to send password reset SMS: #{e.message}"
             render json: { error: 'Не удалось отправить SMS' }, status: :internal_server_error
           end
         else
           render json: { error: 'У пользователя нет email или телефона для отправки инструкций' }, status: :unprocessable_entity
         end
        else
          Rails.logger.error "Failed to save password reset token for user: #{user.id}"
          render json: { error: 'Не удалось создать токен восстановления' }, status: :internal_server_error
        end
      end
      
      # POST /api/v1/password/reset
      # Сброс пароля по токену
      def reset
        token = params[:token]
        password = params[:password]
        password_confirmation = params[:password_confirmation]
        
        unless token.present? && password.present? && password_confirmation.present?
          render json: { error: 'Необходимо указать токен, пароль и подтверждение пароля' }, status: :unprocessable_entity
          return
        end
        
        # Ищем пользователя по токену
        user = User.find_by(password_reset_token: token)
        
        unless user
          render json: { error: 'Недействительный токен восстановления' }, status: :unprocessable_entity
          return
        end
        
        # Проверяем, что токен не истёк
        unless user.password_reset_sent_at && user.password_reset_sent_at > Time.current
          render json: { error: 'Токен восстановления истёк' }, status: :unprocessable_entity
          return
        end
        
        # Проверяем совпадение паролей
        unless password == password_confirmation
          render json: { error: 'Пароли не совпадают' }, status: :unprocessable_entity
          return
        end
        
        # Обновляем пароль и очищаем токен
        if user.update(
          password: password,
          password_confirmation: password_confirmation,
          password_reset_token: nil,
          password_reset_sent_at: nil
        )
          Rails.logger.info("Password successfully reset for user: #{user.id}")
          render json: { message: 'Пароль успешно изменён' }
        else
          render json: { 
            error: 'Не удалось изменить пароль',
            details: user.errors.full_messages 
          }, status: :unprocessable_entity
        end
      end
      
      # GET /api/v1/password/verify_token/:token
      # Проверка действительности токена восстановления
      def verify_token
        token = params[:token]
        
        unless token.present?
          render json: { error: 'Токен не указан' }, status: :unprocessable_entity
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
            error: 'Токен недействителен или истёк'
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