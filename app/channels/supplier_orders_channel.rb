# frozen_string_literal: true

# Real-time updates for supplier orders
# Suppliers subscribe to receive live updates for their orders
class SupplierOrdersChannel < ApplicationCable::Channel
  def subscribed
    # Find supplier for current user
    supplier = current_user.supplier
    unless supplier
      reject
      return
    end

    # Subscribe to supplier's orders stream
    stream_from "orders:supplier_#{supplier.id}"
    log_subscription("orders:supplier_#{supplier.id}")
  end

  def unsubscribed
    supplier = current_user&.supplier
    log_unsubscription("orders:supplier_#{supplier&.id}") if supplier
  end

  # Class methods for broadcasting from models/services
  class << self
    # Broadcast new order to supplier
    def broadcast_new_order(order)
      return unless order.supplier_id

      ActionCable.server.broadcast(
        "orders:supplier_#{order.supplier_id}",
        {
          type: 'order_created',
          order: serialize_order(order),
          message: I18n.t('tire_orders.notifications.new_order',
                         client: order.client_name,
                         amount: order.formatted_total)
        }
      )
    end

    # Broadcast order status change to supplier
    def broadcast_status_change(order)
      return unless order.supplier_id

      ActionCable.server.broadcast(
        "orders:supplier_#{order.supplier_id}",
        {
          type: 'order_status_changed',
          order: serialize_order(order),
          old_status: order.status_before_last_save,
          new_status: order.status,
          message: I18n.t('tire_orders.notifications.status_changed',
                         id: order.id,
                         status: order.status_display)
        }
      )
    end

    # Broadcast order cancellation to supplier
    def broadcast_cancellation(order)
      return unless order.supplier_id

      ActionCable.server.broadcast(
        "orders:supplier_#{order.supplier_id}",
        {
          type: 'order_cancelled',
          order: serialize_order(order),
          message: I18n.t('tire_orders.notifications.cancelled',
                         id: order.id,
                         client: order.client_name)
        }
      )
    end

    # Broadcast order update (tracking, notes, etc.)
    def broadcast_update(order)
      return unless order.supplier_id

      ActionCable.server.broadcast(
        "orders:supplier_#{order.supplier_id}",
        {
          type: 'order_updated',
          order: serialize_order(order),
          message: I18n.t('tire_orders.notifications.updated', id: order.id)
        }
      )
    end

    private

    def serialize_order(order)
      {
        id: order.id,
        status: order.status,
        status_display: order.status_display,
        status_color: order.status_color,
        client_name: order.client_name,
        client_phone: order.client_phone,
        total_amount: order.total_amount,
        formatted_total: order.formatted_total,
        items_count: order.items_count,
        tracking_number: order.tracking_number,
        partner_name: order.ordering_partner&.company_name,
        submitted_at: order.created_at,
        shipped_at: order.shipped_at,
        delivered_at: order.delivered_at,
        created_at: order.created_at,
        updated_at: order.updated_at
      }
    end
  end
end
