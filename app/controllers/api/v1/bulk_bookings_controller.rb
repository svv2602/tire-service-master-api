# frozen_string_literal: true

module Api
  module V1
    class BulkBookingsController < ApiController
      before_action :ensure_partner_access
      before_action :set_partner
      before_action :validate_booking_ids

      # POST /api/v1/partners/:partner_id/bulk_bookings/confirm
      # Mass confirm bookings
      def confirm
        results = process_bookings(:confirm)
        render json: build_response(results, 'confirm')
      end

      # POST /api/v1/partners/:partner_id/bulk_bookings/cancel
      # Mass cancel bookings
      def cancel
        reason_id = params[:cancellation_reason_id]
        comment = params[:cancellation_comment]

        results = process_bookings(:cancel, reason_id: reason_id, comment: comment)
        render json: build_response(results, 'cancel')
      end

      # POST /api/v1/partners/:partner_id/bulk_bookings/reschedule
      # Mass reschedule bookings to a new date/time
      def reschedule
        new_date = params[:new_date]
        new_time = params[:new_time]
        keep_original_time = params[:keep_original_time] || false

        unless new_date.present?
          render json: { error: 'new_date is required' }, status: :unprocessable_entity
          return
        end

        results = process_bookings(:reschedule, new_date: new_date, new_time: new_time, keep_original_time: keep_original_time)
        render json: build_response(results, 'reschedule')
      end

      # POST /api/v1/partners/:partner_id/bulk_bookings/complete
      # Mass complete bookings
      def complete
        results = process_bookings(:complete)
        render json: build_response(results, 'complete')
      end

      # POST /api/v1/partners/:partner_id/bulk_bookings/no_show
      # Mass mark bookings as no-show
      def no_show
        results = process_bookings(:no_show)
        render json: build_response(results, 'no_show')
      end

      # GET /api/v1/partners/:partner_id/bulk_bookings/preview
      # Preview affected bookings before bulk operation
      def preview
        bookings = partner_bookings.where(id: booking_ids).includes(:service_point, client: :user)

        render json: {
          count: bookings.count,
          bookings: bookings.map do |b|
            {
              id: b.id,
              status: b.status,
              booking_date: b.booking_date,
              start_time: b.start_time&.strftime('%H:%M'),
              service_point_name: b.service_point&.name,
              client_name: b.service_recipient_full_name,
              client_phone: b.service_recipient_phone,
              can_confirm: b.can_transition_to?(:confirmed),
              can_cancel: b.can_transition_to?(:cancelled_by_partner),
              can_complete: b.can_transition_to?(:completed),
              can_reschedule: %w[pending confirmed].include?(b.status)
            }
          end
        }
      end

      private

      def ensure_partner_access
        unless current_user&.partner? || current_user&.manager? || current_user&.operator? || current_user&.admin?
          render json: { error: 'Access denied' }, status: :forbidden
        end
      end

      def set_partner
        partner_id = params[:partner_id] || params[:id]
        if current_user.admin?
          @partner = Partner.find(partner_id)
        else
          @partner = current_user.partner
          if partner_id.to_i != @partner.id
            render json: { error: 'Access denied' }, status: :forbidden
          end
        end
      end

      def validate_booking_ids
        return if action_name == 'preview'

        unless booking_ids.is_a?(Array) && booking_ids.any?
          render json: { error: 'booking_ids must be a non-empty array' }, status: :unprocessable_entity
        end
      end

      def booking_ids
        @booking_ids ||= Array(params[:booking_ids]).map(&:to_i)
      end

      def partner_bookings
        Booking.joins(:service_point).where(service_points: { partner_id: @partner.id })
      end

      def process_bookings(action, options = {})
        bookings = partner_bookings.where(id: booking_ids)
        results = { success: [], failed: [] }

        bookings.find_each do |booking|
          result = process_single_booking(booking, action, options)
          if result[:success]
            results[:success] << { id: booking.id, status: booking.status }
          else
            results[:failed] << { id: booking.id, error: result[:error] }
          end
        end

        # Track bookings that weren't found
        found_ids = bookings.pluck(:id)
        missing_ids = booking_ids - found_ids
        missing_ids.each do |id|
          results[:failed] << { id: id, error: 'Booking not found or access denied' }
        end

        results
      end

      def process_single_booking(booking, action, options)
        case action
        when :confirm
          process_confirm(booking)
        when :cancel
          process_cancel(booking, options[:reason_id], options[:comment])
        when :reschedule
          process_reschedule(booking, options[:new_date], options[:new_time], options[:keep_original_time])
        when :complete
          process_complete(booking)
        when :no_show
          process_no_show(booking)
        else
          { success: false, error: "Unknown action: #{action}" }
        end
      rescue StandardError => e
        { success: false, error: e.message }
      end

      def process_confirm(booking)
        return { success: false, error: 'Cannot confirm from current status' } unless booking.can_transition_to?(:confirmed)

        booking.confirm!
        send_confirmation_notification(booking)
        log_bulk_action('confirm', booking)
        { success: true }
      end

      def process_cancel(booking, reason_id, comment)
        return { success: false, error: 'Cannot cancel from current status' } unless booking.can_transition_to?(:cancelled_by_partner)

        Booking.transaction do
          booking.cancel_by_partner!
          booking.update(cancellation_reason_id: reason_id, cancellation_comment: comment) if reason_id.present?
        end

        send_cancellation_notification(booking)
        log_bulk_action('cancel', booking, { reason_id: reason_id, comment: comment })
        { success: true }
      end

      def process_reschedule(booking, new_date, new_time, keep_original_time)
        unless %w[pending confirmed].include?(booking.status)
          return { success: false, error: 'Can only reschedule pending or confirmed bookings' }
        end

        parsed_date = Date.parse(new_date.to_s)
        return { success: false, error: 'Cannot reschedule to a past date' } if parsed_date < Date.current

        updates = { booking_date: parsed_date }
        updates[:start_time] = new_time if new_time.present? && !keep_original_time

        old_date = booking.booking_date
        old_time = booking.start_time

        if booking.update(updates)
          send_reschedule_notification(booking, old_date, old_time)
          log_bulk_action('reschedule', booking, { old_date: old_date, old_time: old_time })
          { success: true }
        else
          { success: false, error: booking.errors.full_messages.join(', ') }
        end
      end

      def process_complete(booking)
        return { success: false, error: 'Cannot complete from current status' } unless booking.can_transition_to?(:completed)

        booking.complete!
        log_bulk_action('complete', booking)
        { success: true }
      end

      def process_no_show(booking)
        return { success: false, error: 'Cannot mark as no-show from current status' } unless booking.can_transition_to?(:no_show)

        booking.mark_no_show!
        log_bulk_action('no_show', booking)
        { success: true }
      end

      def build_response(results, action)
        {
          action: action,
          total_requested: booking_ids.count,
          success_count: results[:success].count,
          failed_count: results[:failed].count,
          successful: results[:success],
          failed: results[:failed]
        }
      end

      def send_confirmation_notification(booking)
        SmsService.send_booking_confirmation(booking.service_recipient_phone, booking) if booking.service_recipient_phone.present?
      rescue StandardError => e
        Rails.logger.error "Failed to send confirmation SMS for booking #{booking.id}: #{e.message}"
      end

      def send_cancellation_notification(booking)
        # Notification will be sent via existing callbacks in Booking model
      end

      def send_reschedule_notification(booking, old_date, old_time)
        # Notification will be sent via existing callbacks in Booking model
      end

      def log_bulk_action(action, booking, extra_data = {})
        return unless defined?(AuditLog)

        AuditLog.create(
          user_id: current_user.id,
          action: "bulk_#{action}",
          auditable_type: 'Booking',
          auditable_id: booking.id,
          changes: extra_data.merge(
            partner_id: @partner.id,
            new_status: booking.status
          )
        )
      rescue StandardError => e
        Rails.logger.error "Failed to log bulk action: #{e.message}"
      end
    end
  end
end
