class NotificationMailer < ApplicationMailer
  layout 'mailer'
  
  # Отправка общего уведомления
  def general_notification(notification_id, recipient_email)
    @notification = Notification.find(notification_id)
    @recipient_email = recipient_email
    
    mail(
      to: recipient_email,
      subject: @notification.title,
      template_path: 'notification_mailer',
      template_name: 'general_notification'
    )
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Notification with ID #{notification_id} not found"
    nil
  end
  
  # Системные уведомления администраторам
  def system_alert(title, message, admin_emails)
    @title = title
    @message = message
    
    mail(
      to: admin_emails,
      subject: "[СИСТЕМА] #{title}",
      template_path: 'notification_mailer', 
      template_name: 'system_alert'
    )
  end
  
  # Еженедельные сводки
  def weekly_summary(recipient_email, summary_data)
    @summary_data = summary_data
    @recipient_email = recipient_email
    
    mail(
      to: recipient_email,
      subject: 'Еженедельная сводка уведомлений',
      template_path: 'notification_mailer',
      template_name: 'weekly_summary'
    )
  end
end 