# frozen_string_literal: true

module Api
  module V1
    class OperatorSchedulesController < ApiController
      skip_after_action :verify_authorized
      before_action :authenticate_user!
      before_action :set_service_point
      before_action :ensure_access
      before_action :set_schedule, only: [:show, :update, :destroy, :confirm, :unconfirm]

      # GET /api/v1/service_points/:service_point_id/operator_schedules
      def index
        schedules = @service_point.operator_schedules
                                  .includes(operator: :user, confirmed_by: [])

        # Apply filters
        schedules = apply_filters(schedules)

        # Sorting
        schedules = schedules.order(schedule_date: :asc, start_time: :asc)

        # Pagination
        paginated = paginate(schedules)

        render json: {
          schedules: ActiveModelSerializers::SerializableResource.new(
            paginated[:data],
            each_serializer: OperatorScheduleSerializer
          ),
          pagination: paginated[:pagination],
          stats: schedules_stats(schedules)
        }
      end

      # GET /api/v1/service_points/:service_point_id/operator_schedules/:id
      def show
        render json: @schedule, serializer: OperatorScheduleSerializer
      end

      # POST /api/v1/service_points/:service_point_id/operator_schedules
      def create
        @schedule = @service_point.operator_schedules.new(schedule_params)

        if @schedule.save
          Rails.logger.info "Operator schedule created: operator #{@schedule.operator_id} on #{@schedule.schedule_date}"
          render json: @schedule, serializer: OperatorScheduleSerializer, status: :created
        else
          render json: { errors: @schedule.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/service_points/:service_point_id/operator_schedules/bulk_create
      def bulk_create
        schedules = []
        errors = []

        ActiveRecord::Base.transaction do
          bulk_params[:schedules].each_with_index do |schedule_data, index|
            schedule = @service_point.operator_schedules.new(
              operator_id: schedule_data[:operator_id],
              schedule_date: schedule_data[:schedule_date],
              start_time: schedule_data[:start_time],
              end_time: schedule_data[:end_time],
              shift_type: schedule_data[:shift_type] || 'regular',
              notes: schedule_data[:notes]
            )

            if schedule.save
              schedules << schedule
            else
              errors << { index: index, errors: schedule.errors.full_messages }
            end
          end

          raise ActiveRecord::Rollback if errors.any?
        end

        if errors.any?
          render json: { errors: errors }, status: :unprocessable_entity
        else
          render json: {
            message: "Created #{schedules.count} schedules",
            schedules: ActiveModelSerializers::SerializableResource.new(
              schedules,
              each_serializer: OperatorScheduleSerializer
            )
          }, status: :created
        end
      end

      # PATCH/PUT /api/v1/service_points/:service_point_id/operator_schedules/:id
      def update
        if @schedule.update(schedule_params)
          Rails.logger.info "Operator schedule updated: #{@schedule.id}"
          render json: @schedule, serializer: OperatorScheduleSerializer
        else
          render json: { errors: @schedule.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/service_points/:service_point_id/operator_schedules/:id
      def destroy
        @schedule.destroy
        Rails.logger.info "Operator schedule deleted: #{@schedule.id}"
        head :no_content
      end

      # POST /api/v1/service_points/:service_point_id/operator_schedules/:id/confirm
      def confirm
        @schedule.confirm!(current_user)
        Rails.logger.info "Operator schedule confirmed: #{@schedule.id} by user #{current_user.id}"
        render json: @schedule, serializer: OperatorScheduleSerializer
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # POST /api/v1/service_points/:service_point_id/operator_schedules/:id/unconfirm
      def unconfirm
        @schedule.unconfirm!
        Rails.logger.info "Operator schedule unconfirmed: #{@schedule.id}"
        render json: @schedule, serializer: OperatorScheduleSerializer
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # GET /api/v1/service_points/:service_point_id/operator_schedules/weekly
      def weekly
        start_date = params[:start_date]&.to_date || Date.current.beginning_of_week
        end_date = start_date + 6.days

        schedules = @service_point.operator_schedules
                                  .includes(operator: :user)
                                  .for_date_range(start_date, end_date)
                                  .order(schedule_date: :asc, start_time: :asc)

        # Group by date
        grouped = schedules.group_by(&:schedule_date).transform_values do |day_schedules|
          {
            schedules: ActiveModelSerializers::SerializableResource.new(
              day_schedules,
              each_serializer: OperatorScheduleSerializer
            ),
            total_hours: day_schedules.sum(&:duration_hours),
            operators_count: day_schedules.map(&:operator_id).uniq.count
          }
        end

        render json: {
          start_date: start_date,
          end_date: end_date,
          days: grouped,
          summary: {
            total_schedules: schedules.count,
            total_hours: schedules.sum(&:duration_hours),
            confirmed_count: schedules.confirmed.count,
            unconfirmed_count: schedules.unconfirmed.count
          }
        }
      end

      # GET /api/v1/service_points/:service_point_id/operator_schedules/available_operators
      def available_operators
        date = params[:date]&.to_date || Date.current
        time = params[:time]

        operators = if time.present?
                      OperatorSchedule.operators_available_at(@service_point.id, date, time)
                    else
                      @service_point.operator_schedules
                                    .for_date(date)
                                    .confirmed
                                    .includes(operator: :user)
                                    .map(&:operator)
                                    .uniq
                    end

        render json: {
          date: date,
          time: time,
          operators: operators.map do |op|
            {
              id: op.id,
              position: op.position,
              user: op.user ? {
                id: op.user.id,
                first_name: op.user.first_name,
                last_name: op.user.last_name,
                full_name: "#{op.user.first_name} #{op.user.last_name}"
              } : nil
            }
          end
        }
      end

      # GET /api/v1/service_points/:service_point_id/operator_schedules/load
      def load
        start_date = params[:start_date]&.to_date || Date.current
        end_date = params[:end_date]&.to_date || (start_date + 6.days)

        load_data = (start_date..end_date).map do |date|
          schedules = @service_point.operator_schedules.for_date(date).confirmed
          total_hours = schedules.sum(&:duration_hours)
          operators_count = schedules.map(&:operator_id).uniq.count

          {
            date: date.strftime('%Y-%m-%d'),
            operators_count: operators_count,
            total_hours: total_hours,
            load_percentage: OperatorSchedule.load_for_date(@service_point.id, date)
          }
        end

        render json: {
          start_date: start_date,
          end_date: end_date,
          load_data: load_data
        }
      end

      private

      def set_service_point
        @service_point = ServicePoint.find(params[:service_point_id])
      end

      def set_schedule
        @schedule = @service_point.operator_schedules.find(params[:id])
      end

      def ensure_access
        # Admin has full access
        return if current_user.admin?

        # Partner can access their service points
        if current_user.partner?
          partner = current_user.partner
          unless partner && @service_point.partner_id == partner.id
            render json: { error: 'Access denied' }, status: :forbidden
          end
          return
        end

        # Manager can access assigned service points
        if current_user.manager?
          manager = current_user.manager
          unless manager && manager.service_points.exists?(id: @service_point.id)
            render json: { error: 'Access denied' }, status: :forbidden
          end
          return
        end

        # Operator can view their own schedules
        if current_user.operator?
          operator = current_user.operator
          unless operator && operator.service_points.exists?(id: @service_point.id)
            render json: { error: 'Access denied' }, status: :forbidden
          end
          return
        end

        render json: { error: 'Access denied' }, status: :forbidden
      end

      def schedule_params
        params.require(:operator_schedule).permit(
          :operator_id, :schedule_date, :start_time, :end_time,
          :shift_type, :notes, :is_confirmed
        )
      end

      def bulk_params
        params.permit(schedules: [:operator_id, :schedule_date, :start_time, :end_time, :shift_type, :notes])
      end

      def apply_filters(scope)
        scope = scope.for_operator(params[:operator_id]) if params[:operator_id].present?
        scope = scope.for_date(params[:date].to_date) if params[:date].present?
        scope = scope.for_date_range(params[:start_date].to_date, params[:end_date].to_date) if params[:start_date].present? && params[:end_date].present?
        scope = scope.by_shift_type(params[:shift_type]) if params[:shift_type].present?
        scope = scope.confirmed if params[:confirmed] == 'true'
        scope = scope.unconfirmed if params[:confirmed] == 'false'
        scope
      end

      def schedules_stats(schedules)
        {
          total: schedules.count,
          confirmed: schedules.confirmed.count,
          unconfirmed: schedules.unconfirmed.count,
          total_hours: schedules.sum(&:duration_hours).round(2),
          by_shift_type: schedules.group(:shift_type).count
        }
      end

      def paginate(scope)
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 25).to_i
        per_page = [per_page, 100].min # Max 100 per page

        total_count = scope.count
        total_pages = (total_count.to_f / per_page).ceil

        data = scope.offset((page - 1) * per_page).limit(per_page)

        {
          data: data,
          pagination: {
            current_page: page,
            per_page: per_page,
            total_count: total_count,
            total_pages: total_pages
          }
        }
      end
    end
  end
end
