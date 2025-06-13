class NotificationMailer < ApplicationMailer
  default from: ENV.fetch('DEFAULT_FROM_EMAIL', 'noreply@tireservice.com')

  # Ежедневная сводка для партнера
  def daily_summary(partner_id, date = Date.current)
    @partner = Partner.find_by(id: partner_id)
    return unless @partner && @partner.email.present?

    @date = date
    @service_points = @partner.service_points
    @bookings = Booking.joins(:service_point)
                       .where(service_points: { partner_id: partner_id })
                       .where(booking_date: date)
                       .order(:start_time)

    mail(
      to: @partner.email,
      subject: "Ежедневная сводка записей на #{date.strftime('%d.%m.%Y')}"
    )
  end

  # Системное оповещение
  def system_alert(message, recipient)
    @message = message
    @timestamp = Time.current
    
    mail(
      to: recipient,
      subject: "Системное уведомление"
    )
  end

  # Пакетная отправка напоминаний о бронированиях
  def booking_reminders_batch(bookings_ids)
    @bookings = Booking.where(id: bookings_ids).includes(:client, :service_point)
    
    @bookings.each do |booking|
      next unless booking.client && booking.client.email.present?
      
      @booking = booking
      @service_point = booking.service_point
      @date = booking.booking_date
      @time = "#{booking.start_time} - #{booking.end_time}"
      
      mail(
        to: booking.client.email,
        subject: "Напоминание о записи на шиномонтаж"
      ) do |format|
        format.html { render 'booking_mailer/booking_reminder' }
        format.text { render 'booking_mailer/booking_reminder' }
      end
    end
  end
end 