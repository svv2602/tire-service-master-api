class PasswordResetMailer < ApplicationMailer
  default from: 'noreply@tire-service.com'

  def reset_instructions(user, token)
    @user = user
    @token = token
    @reset_url = "#{ENV['FRONTEND_URL'] || 'http://localhost:3000'}/reset-password?token=#{token}"
    
    mail(
      to: @user.email,
      subject: 'Восстановление пароля - Tire Service'
    )
  end
end 