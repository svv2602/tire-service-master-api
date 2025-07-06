module Api
  module V1
    class LocaleController < ApplicationController
      skip_before_action :authenticate_request

      # GET /api/v1/locale
      def show
        render json: { locale: I18n.locale }
      end

      # PUT /api/v1/locale
      def update
        locale = params[:locale].to_s.downcase
        
        if User::SUPPORTED_LOCALES.include?(locale)
          if current_user
            if current_user.set_locale(locale)
              render json: { locale: locale, message: I18n.t('locale.updated') }
            else
              render json: { error: I18n.t('locale.update_failed') }, status: :unprocessable_entity
            end
          else
            # Для неавторизованных пользователей просто устанавливаем локаль для текущего запроса
            I18n.locale = locale
            render json: { locale: locale, message: I18n.t('locale.updated_for_session') }
          end
        else
          render json: { error: I18n.t('locale.invalid') }, status: :unprocessable_entity
        end
      end
    end
  end
end 