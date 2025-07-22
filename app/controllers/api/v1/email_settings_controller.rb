class Api::V1::EmailSettingsController < ApplicationController
  before_action :authenticate_request
  before_action :set_email_settings, only: [:show, :update, :test_email]

  # GET /api/v1/email_settings
  def show
    authorize EmailSetting, :show?
    
    render json: {
      email_settings: format_settings(@email_settings),
      statistics: get_email_statistics
    }
  end

  # PATCH/PUT /api/v1/email_settings
  def update
    authorize EmailSetting, :update?
    
    if @email_settings.update(email_settings_params)
      # Обновляем конфигурацию ActionMailer
      update_actionmailer_config
      
      render json: {
        message: 'Настройки почты успешно обновлены',
        email_settings: format_settings(@email_settings)
      }
    else
      render json: {
        errors: @email_settings.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/email_settings/test_email
  def test_email
    authorize EmailSetting, :update?
    
    test_email_address = params[:email] || current_user.email
    
    unless test_email_address.present?
      render json: {
        success: false,
        message: 'Email адрес не указан'
      }, status: :unprocessable_entity
      return
    end
    
    begin
      # Временно применяем настройки для теста
      original_config = ActionMailer::Base.smtp_settings.dup
      ActionMailer::Base.smtp_settings = @email_settings.to_actionmailer_config
      
      # Отправляем тестовое письмо
      TestMailer.smtp_test_email(
        test_email_address,
        @email_settings.effective_from_email,
        @email_settings.effective_from_name
      ).deliver_now
      
      render json: {
        success: true,
        message: 'Тестовое письмо отправлено успешно',
        sent_to: test_email_address
      }
      
    rescue => e
      render json: {
        success: false,
        message: "Ошибка отправки: #{e.message}"
      }, status: :unprocessable_entity
    ensure
      # Восстанавливаем оригинальную конфигурацию
      ActionMailer::Base.smtp_settings = original_config if original_config
    end
  end

  private

  def set_email_settings
    @email_settings = EmailSetting.current
  end

  def email_settings_params
    permitted_params = params.require(:email_settings).permit(
      :smtp_host, :smtp_port, :smtp_username, :smtp_password, :smtp_authentication,
      :smtp_starttls_auto, :smtp_tls, :from_email, :from_name, :enabled, :test_mode,
      :openssl_verify_mode
    )
    
    # Преобразуем пустые строки в nil для полей, которые могут быть пустыми
    [:smtp_host, :smtp_username, :smtp_password, :from_email, :from_name].each do |field|
      if permitted_params[field].present? && permitted_params[field].strip.empty?
        permitted_params[field] = nil
      end
    end
    
    permitted_params
  end

  def format_settings(settings)
    {
      id: settings.id,
      smtp_host: settings.smtp_host,
      smtp_port: settings.smtp_port,
      smtp_username: settings.smtp_username,
      smtp_password: settings.smtp_password.present? ? "••••••••" : nil,
      smtp_authentication: settings.smtp_authentication,
      smtp_starttls_auto: settings.smtp_starttls_auto,
      smtp_tls: settings.smtp_tls,
      openssl_verify_mode: settings.openssl_verify_mode,
      from_email: settings.from_email,
      from_name: settings.from_name,
      enabled: settings.enabled,
      test_mode: settings.test_mode,
      system_status: settings.system_status,
      status_color: settings.status_color,
      status_text: settings.status_text,
      ready_for_production: settings.ready_for_production?,
      valid_configuration: settings.valid_configuration?,
      created_at: settings.created_at,
      updated_at: settings.updated_at
    }
  end

  def get_email_statistics
    {
      total_sent: 0, # TODO: интеграция со статистикой отправки
      total_failed: 0,
      success_rate: 0,
      last_sent_at: nil
    }
  end

  def update_actionmailer_config
    return unless @email_settings.enabled? && @email_settings.valid_configuration?
    
    ActionMailer::Base.smtp_settings = @email_settings.to_actionmailer_config
    ActionMailer::Base.default_options = {
      from: "#{@email_settings.effective_from_name} <#{@email_settings.effective_from_email}>"
    }
  end
end 