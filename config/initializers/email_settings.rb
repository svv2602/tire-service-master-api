# Интеграция настроек email из базы данных с ActionMailer
Rails.application.configure do
  config.after_initialize do
    # Проверяем, что модель EmailSetting существует и таблица создана
    if defined?(EmailSetting) && EmailSetting.table_exists?
      begin
        email_setting = EmailSetting.first
        
        if email_setting&.enabled?
          Rails.logger.info "📧 Применяем настройки email из базы данных"
          
          # Настраиваем SMTP для ActionMailer
          ActionMailer::Base.smtp_settings = {
            address: email_setting.smtp_host,
            port: email_setting.smtp_port || 587,
            user_name: email_setting.smtp_username,
            password: email_setting.smtp_password,
            authentication: email_setting.smtp_authentication || 'plain',
            enable_starttls_auto: email_setting.smtp_starttls_auto.nil? ? true : email_setting.smtp_starttls_auto,
            openssl_verify_mode: email_setting.openssl_verify_mode || 'none'
          }
          
          # Настраиваем delivery_method
          ActionMailer::Base.delivery_method = :smtp
          
          # Настраиваем default from
          if email_setting.from_email.present?
            from_address = email_setting.from_name.present? ? 
              "#{email_setting.from_name} <#{email_setting.from_email}>" : 
              email_setting.from_email
              
            EmailTemplateMailer.default from: from_address
            ApplicationMailer.default from: from_address
          end
          
          Rails.logger.info "✅ Email настройки применены: #{email_setting.smtp_host}:#{email_setting.smtp_port}"
        else
          Rails.logger.warn "⚠️ Email настройки отключены в базе данных"
          
          # Отключаем доставку email если настройки отключены
          ActionMailer::Base.delivery_method = :test if Rails.env.development?
        end
        
      rescue => e
        Rails.logger.error "❌ Ошибка применения email настроек: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        # В случае ошибки используем fallback на ENV переменные
        if ENV['SMTP_ADDRESS'].present?
          Rails.logger.info "📧 Используем fallback на ENV переменные"
          ActionMailer::Base.smtp_settings = {
            address: ENV['SMTP_ADDRESS'],
            port: ENV['SMTP_PORT']&.to_i || 587,
            domain: ENV['SMTP_DOMAIN'],
            user_name: ENV['SMTP_USERNAME'],
            password: ENV['SMTP_PASSWORD'],
            authentication: 'plain',
            enable_starttls_auto: true
          }
        end
      end
    else
      Rails.logger.warn "⚠️ EmailSetting модель не найдена, используем ENV переменные"
    end
  end
end 