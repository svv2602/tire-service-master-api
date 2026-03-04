# frozen_string_literal: true

# Real-time admin metrics channel
# Admins subscribe to receive live KPI updates when:
# - New booking is created
# - New order is placed
# - New user registers
class AdminMetricsChannel < ApplicationCable::Channel
  def subscribed
    unless current_user.admin?
      reject
      return
    end

    stream_from 'admin_metrics'
    log_subscription('admin_metrics')
  end

  def unsubscribed
    log_unsubscription('admin_metrics')
  end

  # Class methods for broadcasting metrics updates
  class << self
    # Broadcast when a new booking is created
    def broadcast_new_booking(booking)
      broadcast_metric_update(
        event: 'new_booking',
        data: {
          booking_id: booking.id,
          service_point_name: booking.service_point&.name,
          city: booking.service_point&.city&.name,
          status: booking.status,
          total_price: booking.total_price
        },
        counters: current_counters
      )
    end

    # Broadcast when a new tire order is created
    def broadcast_new_order(order)
      broadcast_metric_update(
        event: 'new_order',
        data: {
          order_id: order.id,
          total_amount: order.total_amount,
          supplier_name: order.supplier&.name,
          status: order.status
        },
        counters: current_counters
      )
    end

    # Broadcast when a new user registers
    def broadcast_new_user(user)
      broadcast_metric_update(
        event: 'new_user',
        data: {
          user_id: user.id,
          role: user.role&.name,
          created_at: user.created_at&.iso8601
        },
        counters: current_counters
      )
    end

    # Broadcast when a booking status changes
    def broadcast_booking_status_change(booking)
      broadcast_metric_update(
        event: 'booking_status_changed',
        data: {
          booking_id: booking.id,
          old_status: booking.status_before_last_save,
          new_status: booking.status
        },
        counters: current_counters
      )
    end

    private

    def broadcast_metric_update(payload)
      ActionCable.server.broadcast(
        'admin_metrics',
        payload.merge(timestamp: Time.current.iso8601)
      )
    end

    # Current counter snapshot for real-time KPI updates
    def current_counters
      Rails.cache.fetch('admin_metrics:counters', expires_in: 30.seconds) do
        today = Date.current.beginning_of_day

        {
          users_total: User.where(is_active: true).count,
          users_today: User.where(created_at: today..Time.current).count,
          bookings_today: Booking.where(created_at: today..Time.current).count,
          bookings_pending: Booking.where(status: 'pending').count,
          bookings_completed_today: Booking.where(status: 'completed', updated_at: today..Time.current).count,
          orders_today: TireOrder.where(created_at: today..Time.current).where.not(status: 'draft').count,
          revenue_today: Booking.where(status: 'completed', updated_at: today..Time.current)
                                .sum(:total_price).to_f.round(2)
        }
      end
    end
  end
end
