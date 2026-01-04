# frozen_string_literal: true

# Real-time updates for partner bookings
# Partners subscribe to receive live updates for their service points' bookings
class BookingsChannel < ApplicationCable::Channel
  def subscribed
    # Verify user is a partner
    unless current_user.partner?
      reject
      return
    end

    partner = current_user.partner
    unless partner
      reject
      return
    end

    # Subscribe to partner's booking stream
    stream_from "bookings:partner_#{partner.id}"
    log_subscription("bookings:partner_#{partner.id}")
  end

  def unsubscribed
    partner = current_user&.partner
    log_unsubscription("bookings:partner_#{partner&.id}") if partner
  end

  # Class methods for broadcasting from models/services
  class << self
    # Broadcast new booking to partner
    def broadcast_new_booking(booking)
      partner_id = booking.service_point&.partner_id
      return unless partner_id

      ActionCable.server.broadcast(
        "bookings:partner_#{partner_id}",
        {
          type: 'booking_created',
          booking: serialize_booking(booking),
          message: I18n.t('bookings.notifications.new_booking',
                         client: booking.service_recipient_full_name,
                         date: I18n.l(booking.booking_date, format: :short))
        }
      )
    end

    # Broadcast booking status change to partner
    def broadcast_status_change(booking)
      partner_id = booking.service_point&.partner_id
      return unless partner_id

      ActionCable.server.broadcast(
        "bookings:partner_#{partner_id}",
        {
          type: 'booking_status_changed',
          booking: serialize_booking(booking),
          old_status: booking.status_before_last_save,
          new_status: booking.status,
          message: I18n.t('bookings.notifications.status_changed',
                         id: booking.id,
                         status: booking.status)
        }
      )
    end

    # Broadcast booking cancellation to partner
    def broadcast_cancellation(booking)
      partner_id = booking.service_point&.partner_id
      return unless partner_id

      ActionCable.server.broadcast(
        "bookings:partner_#{partner_id}",
        {
          type: 'booking_cancelled',
          booking: serialize_booking(booking),
          reason: booking.cancellation_reason&.name,
          message: I18n.t('bookings.notifications.cancelled',
                         id: booking.id,
                         client: booking.service_recipient_full_name)
        }
      )
    end

    # Broadcast booking update (time, services, etc.)
    def broadcast_update(booking)
      partner_id = booking.service_point&.partner_id
      return unless partner_id

      ActionCable.server.broadcast(
        "bookings:partner_#{partner_id}",
        {
          type: 'booking_updated',
          booking: serialize_booking(booking),
          message: I18n.t('bookings.notifications.updated', id: booking.id)
        }
      )
    end

    private

    def serialize_booking(booking)
      {
        id: booking.id,
        status: booking.status,
        booking_date: booking.booking_date,
        start_time: booking.start_time&.strftime('%H:%M'),
        end_time: booking.end_time&.strftime('%H:%M'),
        client_name: booking.service_recipient_full_name,
        client_phone: booking.service_recipient_phone,
        service_point_id: booking.service_point_id,
        service_point_name: booking.service_point&.name,
        car_info: [booking.car_brand, booking.car_model, booking.license_plate].compact.join(' '),
        total_price: booking.total_price,
        services: booking.services.pluck(:name),
        created_at: booking.created_at,
        updated_at: booking.updated_at
      }
    end
  end
end
