class BookingConflictAnalysisJob < ApplicationJob
  queue_as :default

  def perform(service_point_id: nil, post_id: nil, seasonal_schedule_id: nil, analysis_date: nil)
    Rails.logger.info "Starting booking conflict analysis job"
    
    # Получаем объекты по ID
    service_point = ServicePoint.find(service_point_id) if service_point_id.present?
    post = ServicePost.find(post_id) if post_id.present?
    seasonal_schedule = SeasonalSchedule.find(seasonal_schedule_id) if seasonal_schedule_id.present?
    
    # Запускаем анализ
    analysis_service = BookingConflictAnalysisService.new(
      service_point: service_point,
      post: post,
      seasonal_schedule: seasonal_schedule,
      analysis_date: analysis_date&.to_date
    )
    
    conflicts = analysis_service.call
    
    Rails.logger.info "Booking conflict analysis completed. Found #{conflicts.count} conflicts"
    
    # Отправляем уведомление администраторам, если найдены новые конфликты
    if conflicts.any?
      notify_administrators(conflicts)
    end
    
    conflicts
  rescue StandardError => e
    Rails.logger.error "Error in booking conflict analysis job: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end

  private

  def notify_administrators(conflicts)
    # Получаем всех администраторов
    administrators = User.joins(:user_roles).where(user_roles: { role: 'admin' })
    
    administrators.each do |admin|
      # Отправляем уведомление по email (если настроена почта)
      if admin.email.present?
        NotificationMailer.booking_conflicts_detected(admin, conflicts).deliver_later
      end
    end
  end
end 