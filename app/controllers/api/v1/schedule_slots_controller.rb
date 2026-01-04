# frozen_string_literal: true

module Api
  module V1
    class ScheduleSlotsController < BaseController
      # Skip auth for public slot viewing and reservation endpoints
      skip_before_action :authenticate_request, only: [
        :index, :show, :available, :reserve, :release, :reserved, :extend_reservation
      ]

      before_action :set_service_point, only: [:index, :available]
      before_action :set_schedule_slot, only: [:show, :update, :destroy, :reserve, :release]

      # GET /api/v1/service_points/:service_point_id/schedule_slots
      # List slots for a service point
      def index
        slots = @service_point.schedule_slots

        # Filter by date
        if params[:date].present?
          slots = slots.where(slot_date: params[:date])
        end

        # Filter by date range
        if params[:start_date].present? && params[:end_date].present?
          slots = slots.by_date_range(params[:start_date], params[:end_date])
        end

        # Filter by post
        if params[:post_id].present?
          slots = slots.for_service_post(params[:post_id])
        end

        # Filter by availability
        slots = slots.available if params[:available_only] == 'true'
        slots = slots.not_reserved if params[:unreserved_only] == 'true'

        slots = slots.order(:slot_date, :start_time)

        render json: {
          success: true,
          slots: slots.map { |slot| slot_json(slot) },
          total: slots.count
        }
      end

      # GET /api/v1/schedule_slots/:id
      def show
        render json: {
          success: true,
          slot: slot_json(@schedule_slot, include_reservation: true)
        }
      end

      # GET /api/v1/service_points/:service_point_id/schedule_slots/available
      # Find available slots for a given duration
      def available
        date = params[:date] || Date.current
        duration = (params[:duration_minutes] || 30).to_i

        options = {}
        options[:post_id] = params[:post_id] if params[:post_id].present?
        options[:start_time] = params[:start_time] if params[:start_time].present?
        options[:end_time] = params[:end_time] if params[:end_time].present?

        # If services are specified, calculate duration from them
        if params[:service_ids].present?
          services = Service.where(id: params[:service_ids])
          car_type = params[:car_type]

          available_windows = ScheduleManager.find_available_slots_for_services(
            @service_point.id, date, services, car_type: car_type
          )
        else
          available_windows = ScheduleManager.find_available_slots_for_duration(
            @service_point.id, date, duration, options
          )
        end

        render json: {
          success: true,
          date: date,
          duration_minutes: duration,
          available_windows: available_windows,
          total: available_windows.count
        }
      end

      # POST /api/v1/schedule_slots/:id/reserve
      # Temporarily reserve a slot
      def reserve
        timeout_minutes = (params[:timeout_minutes] || 10).to_i

        result = ScheduleManager.reserve_slot_temporarily(
          session_id,
          @schedule_slot.id,
          timeout_minutes: timeout_minutes
        )

        if result[:success]
          render json: {
            success: true,
            message: 'Slot reserved successfully',
            slot: slot_json(result[:slot], include_reservation: true),
            reserved_until: result[:reserved_until]&.iso8601,
            remaining_seconds: result[:remaining_seconds],
            session_id: session_id
          }
        else
          render json: {
            success: false,
            error: result[:error],
            message: error_message_for(result[:error])
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/schedule_slots/:id/reserve
      # Release a reserved slot
      def release
        result = ScheduleManager.release_slot(session_id, @schedule_slot.id)

        if result[:success]
          render json: {
            success: true,
            message: 'Slot released successfully'
          }
        else
          render json: {
            success: false,
            error: result[:error],
            message: error_message_for(result[:error])
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/schedule_slots/reserve_multiple
      # Reserve multiple consecutive slots
      def reserve_multiple
        slot_ids = params[:slot_ids]
        timeout_minutes = (params[:timeout_minutes] || 10).to_i

        if slot_ids.blank? || !slot_ids.is_a?(Array)
          return render json: {
            success: false,
            error: 'slot_ids_required',
            message: 'slot_ids array is required'
          }, status: :bad_request
        end

        result = ScheduleManager.reserve_multiple_slots(
          session_id,
          slot_ids,
          timeout_minutes: timeout_minutes
        )

        if result[:success]
          render json: {
            success: true,
            message: 'Slots reserved successfully',
            slots: result[:slots].map { |s| slot_json(s, include_reservation: true) },
            total_duration: result[:total_duration],
            reserved_until: result[:reserved_until]&.iso8601,
            remaining_seconds: result[:remaining_seconds],
            session_id: session_id
          }
        else
          render json: {
            success: false,
            error: result[:error],
            unavailable_slot_id: result[:unavailable_slot_id],
            message: error_message_for(result[:error])
          }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/schedule_slots/reserved
      # Get all slots reserved by current session
      def reserved
        slots = ScheduleManager.get_slots_for_session(session_id)

        render json: {
          success: true,
          session_id: session_id,
          slots: slots.map { |slot| slot_json(slot, include_reservation: true) },
          total: slots.count
        }
      end

      # POST /api/v1/schedule_slots/release_all
      # Release all slots reserved by current session
      def release_all
        result = ScheduleManager.release_all_slots_for_session(session_id)

        render json: {
          success: true,
          message: "Released #{result[:released_count]} slots",
          released_count: result[:released_count]
        }
      end

      # POST /api/v1/schedule_slots/extend_reservation
      # Extend reservation timeout
      def extend_reservation
        additional_minutes = (params[:additional_minutes] || 5).to_i

        result = ScheduleManager.extend_reservation(session_id, additional_minutes: additional_minutes)

        if result[:success]
          render json: {
            success: true,
            message: 'Reservation extended',
            extended_count: result[:extended_count],
            reserved_until: result[:reserved_until]&.iso8601,
            remaining_seconds: result[:remaining_seconds]
          }
        else
          render json: {
            success: false,
            error: result[:error],
            message: error_message_for(result[:error])
          }, status: :unprocessable_entity
        end
      end

      # Admin/Partner endpoints
      # POST /api/v1/service_points/:service_point_id/schedule_slots
      def create
        authorize_service_point!

        @schedule_slot = @service_point.schedule_slots.build(schedule_slot_params)

        if @schedule_slot.save
          render json: {
            success: true,
            slot: slot_json(@schedule_slot)
          }, status: :created
        else
          render json: {
            success: false,
            errors: @schedule_slot.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/schedule_slots/:id
      def update
        authorize_slot_access!

        if @schedule_slot.update(schedule_slot_params)
          render json: {
            success: true,
            slot: slot_json(@schedule_slot)
          }
        else
          render json: {
            success: false,
            errors: @schedule_slot.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/schedule_slots/:id
      def destroy
        authorize_slot_access!

        if @schedule_slot.destroy
          render json: { success: true, message: 'Slot deleted' }
        else
          render json: {
            success: false,
            errors: @schedule_slot.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      private

      def set_service_point
        @service_point = ServicePoint.find(params[:service_point_id])
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, error: 'Service point not found' }, status: :not_found
      end

      def set_schedule_slot
        @schedule_slot = ScheduleSlot.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, error: 'Slot not found' }, status: :not_found
      end

      def schedule_slot_params
        params.require(:schedule_slot).permit(
          :slot_date, :start_time, :end_time, :post_number,
          :service_post_id, :is_available
        )
      end

      def session_id
        params[:session_id] ||
          request.headers['X-Session-ID'] ||
          (session[:booking_session_id] ||= SecureRandom.uuid)
      end

      def slot_json(slot, include_reservation: false)
        json = {
          id: slot.id,
          service_point_id: slot.service_point_id,
          service_post_id: slot.service_post_id,
          post_number: slot.post_number,
          slot_date: slot.slot_date,
          start_time: slot.start_time.strftime('%H:%M'),
          end_time: slot.end_time.strftime('%H:%M'),
          duration_minutes: slot.duration_in_minutes,
          is_available: slot.is_available
        }

        if include_reservation
          json.merge!(
            reservation_status: slot.reservation_status,
            reserved: slot.reserved?,
            reserved_by_current_session: slot.reserved_by?(session_id),
            remaining_seconds: slot.reservation_remaining_seconds
          )
        end

        json
      end

      def error_message_for(error_code)
        case error_code
        when 'slot_not_found'
          'The requested time slot was not found'
        when 'slot_not_available'
          'This time slot is no longer available'
        when 'slots_not_found'
          'One or more slots were not found'
        when 'some_slots_not_available'
          'Some of the requested slots are no longer available'
        when 'slots_not_consecutive'
          'Selected slots must be consecutive on the same service post'
        when 'reservation_failed'
          'Failed to reserve the slot. Please try again'
        when 'release_failed'
          'Failed to release the slot'
        when 'no_reservations'
          'No active reservations found for this session'
        else
          'An error occurred'
        end
      end

      def authorize_service_point!
        return if current_user&.admin?

        unless current_user && @service_point.partner_id == current_user.partner&.id
          render json: { success: false, error: 'Access denied' }, status: :forbidden
        end
      end

      def authorize_slot_access!
        return if current_user&.admin?

        service_point = @schedule_slot.service_point
        unless current_user && service_point.partner_id == current_user.partner&.id
          render json: { success: false, error: 'Access denied' }, status: :forbidden
        end
      end
    end
  end
end
