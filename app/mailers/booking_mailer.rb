class BookingMailer < ApplicationMailer
  default from: ENV.fetch('DEFAULT_FROM_EMAIL', 'noreply@tireservice.com')

  # Уведомление о создании бронирования
  def booking_created(booking_id)
    @booking = Booking.find_by(id: booking_id)
    return unless @booking && @booking.client && @booking.client.email.present?

    @service_point = @booking.service_point
    @date = @booking.booking_date
    @time = "#{@booking.start_time} - #{@booking.end_time}"
    
    mail(
      to: @booking.client.email,
      subject: "Ваша запись на шиномонтаж создана"
    )
  end

  # Уведомление о подтверждении бронирования
  def booking_confirmed(booking_id)
    @booking = Booking.find_by(id: booking_id)
    return unless @booking && @booking.client && @booking.client.email.present?

    @service_point = @booking.service_point
    @date = @booking.booking_date
    @time = "#{@booking.start_time} - #{@booking.end_time}"
    
    mail(
      to: @booking.client.email,
      subject: "Ваша запись на шиномонтаж подтверждена"
    )
  end

  # Напоминание о бронировании
  def booking_reminder(booking_id)
    @booking = Booking.find_by(id: booking_id)
    return unless @booking && @booking.client && @booking.client.email.present?

    @service_point = @booking.service_point
    @date = @booking.booking_date
    @time = "#{@booking.start_time} - #{@booking.end_time}"
    
    mail(
      to: @booking.client.email,
      subject: "Напоминание о записи на шиномонтаж"
    )
  end

  # Уведомление об отмене бронирования
  def booking_cancelled(booking_id)
    @booking = Booking.find_by(id: booking_id)
    return unless @booking && @booking.client && @booking.client.email.present?

    @service_point = @booking.service_point
    @date = @booking.booking_date
    @time = "#{@booking.start_time} - #{@booking.end_time}"
    
    mail(
      to: @booking.client.email,
      subject: "Ваша запись на шиномонтаж отменена"
    )
  end

  # Уведомление о завершении обслуживания
  def booking_completed(booking_id)
    @booking = Booking.find_by(id: booking_id)
    return unless @booking && @booking.client && @booking.client.email.present?

    @service_point = @booking.service_point
    @date = @booking.booking_date
    @time = "#{@booking.start_time} - #{@booking.end_time}"
    
    mail(
      to: @booking.client.email,
      subject: "Спасибо за визит! Оставьте отзыв о нашем сервисе"
    )
  end

  # Уведомление партнеру о новом бронировании
  def new_booking_notification(booking_id, partner_id)
    @booking = Booking.find_by(id: booking_id)
    @partner = Partner.find_by(id: partner_id)
    return unless @booking && @partner && @partner.email.present?

    @service_point = @booking.service_point
    @date = @booking.booking_date
    @time = "#{@booking.start_time} - #{@booking.end_time}"
    @client = @booking.client
    
    mail(
      to: @partner.email,
      subject: "Новая запись на шиномонтаж"
    )
  end

  # Уведомление партнеру об отмене бронирования
  def booking_cancelled_notification(booking_id, partner_id)
    @booking = Booking.find_by(id: booking_id)
    @partner = Partner.find_by(id: partner_id)
    return unless @booking && @partner && @partner.email.present?

    @service_point = @booking.service_point
    @date = @booking.booking_date
    @time = "#{@booking.start_time} - #{@booking.end_time}"
    @client = @booking.client
    
    mail(
      to: @partner.email,
      subject: "Запись на шиномонтаж отменена"
    )
  end
end 