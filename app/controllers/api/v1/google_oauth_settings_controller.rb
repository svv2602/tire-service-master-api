class Api::V1::GoogleOauthSettingsController < ApplicationController
  before_action :authenticate_request
  before_action :set_google_oauth_settings, only: [:show, :update, :test_connection]

  # GET /api/v1/google_oauth_settings
  def show
    authorize GoogleOauthSetting, :show?
    
    render json: {
      google_oauth_settings: format_settings(@google_oauth_settings),
      statistics: get_oauth_statistics
    }
  end

  # PATCH/PUT /api/v1/google_oauth_settings
  def update
    authorize GoogleOauthSetting, :update?
    
    if @google_oauth_settings.update(google_oauth_settings_params)
      render json: {
        message: 'Настройки Google OAuth успешно обновлены',
        google_oauth_settings: format_settings(@google_oauth_settings)
      }
    else
      render json: {
        errors: @google_oauth_settings.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/google_oauth_settings/test_connection
  def test_connection
    authorize GoogleOauthSetting, :update?
    
    unless @google_oauth_settings.valid_configuration?
      render json: {
        success: false,
        message: 'Конфигурация Google OAuth не завершена'
      }, status: :unprocessable_entity
      return
    end
    
    begin
      # Генерируем тестовый URL для авторизации
      test_state = SecureRandom.hex(16)
      auth_url = @google_oauth_settings.authorization_url(test_state)
      
      render json: {
        success: true,
        message: 'Конфигурация Google OAuth корректна',
        authorization_url: auth_url,
        test_state: test_state
      }
      
    rescue => e
      render json: {
        success: false,
        message: "Ошибка генерации URL: #{e.message}"
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/google_oauth_settings/authorization_url
  def authorization_url
    authorize GoogleOauthSetting, :show?
    
    unless @google_oauth_settings.valid_configuration?
      render json: {
        success: false,
        message: 'Google OAuth не настроен'
      }, status: :unprocessable_entity
      return
    end
    
    state = params[:state] || SecureRandom.hex(16)
    auth_url = @google_oauth_settings.authorization_url(state)
    
    render json: {
      authorization_url: auth_url,
      state: state
    }
  end

  private

  def set_google_oauth_settings
    @google_oauth_settings = GoogleOauthSetting.current
  end

  def google_oauth_settings_params
    permitted_params = params.require(:google_oauth_settings).permit(
      :client_id, :client_secret, :redirect_uri, :enabled, 
      :allow_registration, :auto_verify_email, :scopes_list
    )
    
    # Преобразуем пустые строки в nil для полей, которые могут быть пустыми
    [:client_id, :client_secret, :redirect_uri, :scopes_list].each do |field|
      if permitted_params[field].present? && permitted_params[field].strip.empty?
        permitted_params[field] = nil
      end
    end
    
    permitted_params
  end

  def format_settings(settings)
    {
      id: settings.id,
      client_id: settings.client_id,
      client_secret: settings.client_secret.present? ? "••••••••••••••••••••••••" : nil,
      redirect_uri: settings.redirect_uri,
      enabled: settings.enabled,
      allow_registration: settings.allow_registration,
      auto_verify_email: settings.auto_verify_email,
      scopes_list: settings.scopes_list,
      scopes_array: settings.scopes_array,
      system_status: settings.system_status,
      status_color: settings.status_color,
      status_text: settings.status_text,
      ready_for_production: settings.ready_for_production?,
      valid_configuration: settings.valid_configuration?,
      created_at: settings.created_at,
      updated_at: settings.updated_at
    }
  end

  def get_oauth_statistics
    {
      total_logins: 0, # TODO: интеграция со статистикой OAuth
      successful_logins: 0,
      failed_logins: 0,
      success_rate: 0,
      last_login_at: nil
    }
  end
end 