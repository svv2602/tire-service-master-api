# Mailer для тестирования отправки email с использованием шаблонов из БД
class TestMailer < ApplicationMailer
  default from: ENV.fetch('SMTP_FROM_EMAIL', 'noreply@tireservice.ua')

  # Отправка email с использованием шаблона из базы данных
  def send_template_email(template_id, recipient_email, test_variables = {})
    template = EmailTemplate.find(template_id)
    
    # Заменяем переменные в шаблоне
    subject = replace_variables(template.subject, test_variables)
    body = replace_variables(template.body, test_variables)
    
    # Конвертируем переносы строк в HTML (простая замена)
    html_body = body.gsub(/\r\n|\r|\n/, '<br/>').html_safe
    
    mail(
      to: recipient_email,
      subject: subject,
      body: html_body,
      content_type: 'text/html; charset=UTF-8'
    )
  end

  # Простой тестовый email без шаблона
  def simple_test_email(recipient_email)
    sent_at = Time.current.strftime('%d.%m.%Y о %H:%M')
    
    simple_body = %{
      <h2>🧪 Тестове повідомлення</h2>
      <p>Вітаємо!</p>
      <p>Це тестове повідомлення від системи <strong>Tire Service Master</strong>.</p>
      <p>Якщо ви отримали цей лист, значить налаштування пошти працюють коректно.</p>
      <hr>
      <p><small>Відправлено: #{sent_at}</small></p>
      <p><small>Отримувач: #{recipient_email}</small></p>
    }.strip
    
    mail(
      to: recipient_email,
      subject: 'Тестове повідомлення від Tire Service Master',
      body: simple_body,
      content_type: 'text/html; charset=UTF-8'
    )
  end

  private

  # Заменяет переменные в тексте
  def replace_variables(text, variables)
    result = text.dup
    variables.each do |key, value|
      placeholder = "{#{key}}"
      result.gsub!(placeholder, value.to_s)
    end
    result
  end
end 