# frozen_string_literal: true

module ApplicationCable
  # Base channel class for all ActionCable channels
  # Provides common functionality for subscription management
  class Channel < ActionCable::Channel::Base
    # Broadcast helper method for subclasses
    def self.broadcast_to_user(user, data)
      ActionCable.server.broadcast("user_#{user.id}", data)
    end

    # Broadcast helper for partner channels
    def self.broadcast_to_partner(partner, data)
      ActionCable.server.broadcast("partner_#{partner.id}", data)
    end

    # Broadcast helper for supplier channels
    def self.broadcast_to_supplier(supplier, data)
      ActionCable.server.broadcast("supplier_#{supplier.id}", data)
    end

    protected

    # Log subscription events for debugging
    def log_subscription(channel_name)
      Rails.logger.info "[ActionCable] #{current_user&.email} subscribed to #{channel_name}"
    end

    # Log unsubscription events
    def log_unsubscription(channel_name)
      Rails.logger.info "[ActionCable] #{current_user&.email} unsubscribed from #{channel_name}"
    end

    # Access current_user from connection
    delegate :current_user, to: :connection
  end
end
