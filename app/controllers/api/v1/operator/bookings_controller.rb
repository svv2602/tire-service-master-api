module Api
  module V1
    module Operator
      # Mobile-optimized API for operator booking management.
      # Provides endpoints for today's bookings and status transitions
      # scoped to the operator's assigned service points.
      class BookingsController < ApiController
        before_action :ensure_operator!
        before_action :set_booking, only: [:show, :start, :complete, :no_show]

        # GET /api/v1/operator/bookings/today
        # Returns today's bookings for operator's assigned service points.
        def today
          service_point_ids = current_operator_service_point_ids

          if service_point_ids.empty?
            render json: { data: [], message: "No assigned service points" }, status: :ok
            return
          end

          bookings = Booking.includes(:client, :service_point, :car, :services)
                           .where(service_point_id: service_point_ids)
                           .where(booking_date: Date.current)

          # Optional status filter
          if params[:status].present?
            status = BookingStatus.find_by(name: params[:status])
            bookings = bookings.where(status_id: status.id) if status
          end

          bookings = bookings.order(:start_time)

          result = paginate(bookings)

          render json: {
            data: result[:data].map { |b| serialize_booking(b) },
            pagination: result[:pagination],
            stats: build_today_stats(service_point_ids)
          }
        end

        # GET /api/v1/operator/bookings/:id
        # Returns detailed booking info.
        def show
          render json: { data: serialize_booking_detail(@booking) }
        end

        # PATCH /api/v1/operator/bookings/:id/start
        # Transition booking to in_progress status.
        def start
          authorize @booking, :update?

          begin
            if @booking.start!
              update_metrics(@booking)
              log_action('start', 'booking', @booking.id,
                         { status: @booking.status_id_was },
                         { status: @booking.status_id })
              render json: { data: serialize_booking(@booking) }
            else
              render json: { errors: @booking.errors.full_messages }, status: :unprocessable_entity
            end
          rescue StandardError => e
            render json: { errors: e.message }, status: :unprocessable_entity
          end
        end

        # PATCH /api/v1/operator/bookings/:id/complete
        # Mark booking as completed.
        def complete
          authorize @booking, :complete?

          begin
            if @booking.complete!
              update_metrics(@booking)
              log_action('complete', 'booking', @booking.id,
                         { status: @booking.status_id_was },
                         { status: @booking.status_id })
              render json: { data: serialize_booking(@booking) }
            else
              render json: { errors: @booking.errors.full_messages }, status: :unprocessable_entity
            end
          rescue StandardError => e
            render json: { errors: e.message }, status: :unprocessable_entity
          end
        end

        # PATCH /api/v1/operator/bookings/:id/no_show
        # Mark client as no-show.
        def no_show
          authorize @booking, :no_show?

          begin
            if @booking.mark_no_show!
              update_metrics(@booking)
              log_action('no_show', 'booking', @booking.id,
                         { status: @booking.status_id_was },
                         { status: @booking.status_id })
              render json: { data: serialize_booking(@booking) }
            else
              render json: { errors: @booking.errors.full_messages }, status: :unprocessable_entity
            end
          rescue StandardError => e
            render json: { errors: e.message }, status: :unprocessable_entity
          end
        end

        private

        def ensure_operator!
          unless current_user&.operator?
            render json: { error: "Access denied. Operator role required." }, status: :forbidden
          end
        end

        def set_booking
          @booking = Booking.includes(:client, :service_point, :car, :services)
                           .find(params[:id])

          # Verify booking belongs to operator's service points
          unless current_operator_service_point_ids.include?(@booking.service_point_id)
            render json: { error: "Booking not found" }, status: :not_found
          end
        end

        def current_operator_service_point_ids
          @current_operator_service_point_ids ||= begin
            operator = current_user.operator
            return [] unless operator

            OperatorServicePoint.where(operator_id: operator.id, is_active: true)
                               .pluck(:service_point_id)
          end
        end

        def update_metrics(booking)
          if booking.service_point.respond_to?(:recalculate_metrics!)
            booking.service_point.recalculate_metrics!
          end
        end

        def build_today_stats(service_point_ids)
          today_bookings = Booking.where(
            service_point_id: service_point_ids,
            booking_date: Date.current
          )

          # Get status IDs for counting
          pending_status = BookingStatus.find_by(name: 'pending')
          confirmed_status = BookingStatus.find_by(name: 'confirmed')
          in_progress_status = BookingStatus.find_by(name: 'in_progress')
          completed_status = BookingStatus.find_by(name: 'completed')
          no_show_status = BookingStatus.find_by(name: 'no_show')

          {
            total: today_bookings.count,
            pending: pending_status ? today_bookings.where(status_id: pending_status.id).count : 0,
            confirmed: confirmed_status ? today_bookings.where(status_id: confirmed_status.id).count : 0,
            in_progress: in_progress_status ? today_bookings.where(status_id: in_progress_status.id).count : 0,
            completed: completed_status ? today_bookings.where(status_id: completed_status.id).count : 0,
            no_show: no_show_status ? today_bookings.where(status_id: no_show_status.id).count : 0
          }
        end

        # Compact serialization for list view
        def serialize_booking(booking)
          client = booking.client
          car = booking.car

          {
            id: booking.id,
            booking_date: booking.booking_date,
            start_time: booking.start_time&.strftime('%H:%M'),
            end_time: booking.end_time&.strftime('%H:%M'),
            status: booking.status,
            notes: booking.notes,
            client: client ? {
              id: client.id,
              first_name: client.user&.first_name,
              last_name: client.user&.last_name,
              phone: client.user&.phone
            } : nil,
            car: car ? {
              id: car.id,
              brand: car.brand,
              model: car.model,
              year: car.year,
              license_plate: car.license_plate
            } : nil,
            service_point: {
              id: booking.service_point&.id,
              name: booking.service_point&.name
            },
            services: booking.services.map { |s|
              {
                id: s[:service_id] || s['service_id'],
                name: s[:name] || s['name'],
                price: s[:price] || s['price']
              }
            },
            service_category: booking.respond_to?(:service_category) ? booking.service_category : nil,
            created_at: booking.created_at
          }
        end

        # Detailed serialization for single booking view
        def serialize_booking_detail(booking)
          base = serialize_booking(booking)
          base.merge(
            updated_at: booking.updated_at,
            service_point: {
              id: booking.service_point&.id,
              name: booking.service_point&.name,
              address: booking.service_point&.address,
              contact_phone: booking.service_point&.contact_phone
            }
          )
        end
      end
    end
  end
end
