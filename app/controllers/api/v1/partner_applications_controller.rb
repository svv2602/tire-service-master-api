module Api
  module V1
    class PartnerApplicationsController < ApiController
      before_action :set_application, only: [:show, :update, :update_status, :destroy]
      before_action :authorize_admin_or_manager, except: [:create]
      skip_before_action :authenticate_request, only: [:create]

      # GET /api/v1/partner_applications
      # Получение списка заявок с фильтрацией и пагинацией
      def index
        @applications = policy_scope(PartnerApplication)
        
        # Фильтрация по статусу
        if params[:status].present?
          @applications = @applications.by_status(params[:status])
        end
        
        # Фильтрация по региону
        if params[:region_id].present?
          @applications = @applications.by_region(params[:region_id])
        end
        
        # Поиск по названию компании или контактному лицу
        if params[:query].present?
          query = params[:query].strip
          @applications = @applications.where(
            "company_name ILIKE ? OR contact_person ILIKE ? OR email ILIKE ?",
            "%#{query}%", "%#{query}%", "%#{query}%"
          )
        end
        
        # Сортировка
        sort_by = params[:sort_by] || 'created_at'
        sort_direction = params[:sort_direction] || 'desc'
        
        case sort_by
        when 'company_name'
          @applications = @applications.order("company_name #{sort_direction}")
        when 'status'
          @applications = @applications.order("status #{sort_direction}")
        when 'created_at'
          @applications = @applications.order("created_at #{sort_direction}")
        else
          @applications = @applications.recent
        end
        
        # Пагинация
        page = [params[:page].to_i, 1].max
        per_page = [params[:per_page].to_i, 10].max
        per_page = [per_page, 100].min # Максимум 100 записей на страницу
        
        total_count = @applications.count
        @applications = @applications.includes(:region, :city_record, :processed_by)
                                   .offset((page - 1) * per_page)
                                   .limit(per_page)
        
        total_pages = (total_count.to_f / per_page).ceil
        
        render json: {
          data: ActiveModel::Serializer::CollectionSerializer.new(
            @applications,
            serializer: PartnerApplicationSerializer
          ),
          pagination: {
            current_page: page,
            total_pages: total_pages,
            total_count: total_count,
            per_page: per_page
          },
          meta: {
            filters: {
              status: params[:status],
              region_id: params[:region_id],
              query: params[:query]
            },
            sort: {
              sort_by: sort_by,
              sort_direction: sort_direction
            }
          }
        }
      end

      # GET /api/v1/partner_applications/:id
      # Получение детальной информации о заявке
      def show
        authorize @application
        
        render json: {
          data: PartnerApplicationSerializer.new(@application)
        }
      end

      # POST /api/v1/partner_applications
      # Создание новой заявки (публичный endpoint)
      def create
        @application = PartnerApplication.new(application_params)
        
        if @application.save
          # Отправляем уведомление администраторам (если нужно)
          # PartnerApplicationNotificationService.notify_new_application(@application)
          
          render json: {
            message: 'Заявка успешно отправлена! Мы свяжемся с вами в ближайшее время.',
            data: PartnerApplicationSerializer.new(@application)
          }, status: :created
        else
          render json: {
            message: 'Ошибка при отправке заявки',
            errors: @application.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/partner_applications/:id
      # Обновление заметок администратора
      def update
        authorize @application
        
        if @application.update(update_params)
          render json: {
            message: 'Заявка успешно обновлена',
            data: PartnerApplicationSerializer.new(@application)
          }
        else
          render json: {
            message: 'Ошибка при обновлении заявки',
            errors: @application.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/partner_applications/:id/update_status
      # Изменение статуса заявки
      def update_status
        Rails.logger.info "🔍 PartnerApplicationsController#update_status вызван для заявки #{@application.id}"
        Rails.logger.info "🔍 Параметры: status=#{params[:status]}, admin_notes=#{params[:admin_notes]}"
        
        authorize @application, :update_status?
        
        new_status = params[:status]
        admin_notes = params[:admin_notes]
        
        unless PartnerApplication.statuses.key?(new_status)
          return render json: {
            message: 'Некорректный статус',
            available_statuses: PartnerApplication.statuses.keys
          }, status: :unprocessable_entity
        end

        begin
          case new_status
          when 'in_progress'
            @application.mark_as_in_progress!(current_user)
          when 'approved'
            @application.approve!(current_user, admin_notes)
          when 'rejected'
            @application.reject!(current_user, admin_notes)
          when 'connected'
            @application.mark_as_connected!(current_user, admin_notes)
          else
            @application.update!(status: new_status, processed_by: current_user, admin_notes: admin_notes)
          end

          # Отправляем уведомление заявителю об изменении статуса (если нужно)
          # PartnerApplicationNotificationService.notify_status_change(@application, old_status)

          render json: {
            message: "Статус заявки изменен на '#{@application.status_label}'",
            data: PartnerApplicationSerializer.new(@application)
          }
        rescue ActiveRecord::RecordInvalid => e
          render json: {
            message: 'Ошибка при изменении статуса',
            errors: e.record.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/partner_applications/:id
      # Удаление заявки (только для админов)
      def destroy
        authorize @application
        
        if @application.destroy
          render json: {
            message: 'Заявка успешно удалена'
          }
        else
          render json: {
            message: 'Ошибка при удалении заявки',
            errors: @application.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/partner_applications/stats
      # Статистика по заявкам
      def stats
        authorize PartnerApplication, :index?
        
        stats = {
          total: PartnerApplication.count,
          by_status: PartnerApplication.group(:status).count,
          recent_count: PartnerApplication.where('created_at >= ?', 1.week.ago).count,
          processing_average: calculate_average_processing_time
        }
        
        render json: { data: stats }
      end

      private

      def set_application
        @application = PartnerApplication.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: {
          message: 'Заявка не найдена'
        }, status: :not_found
      end

      def authorize_admin_or_manager
        unless current_user&.admin? || current_user&.manager?
          render json: {
            message: 'Доступ запрещен. Необходимы права администратора или менеджера.'
          }, status: :forbidden
        end
      end

      def application_params
        params.require(:partner_application).permit(
          :company_name, :business_description, :contact_person, :email, :phone,
          :city, :address, :region_id, :city_record_id, :website, :additional_info,
          :expected_service_points
        )
      end

      def update_params
        params.require(:partner_application).permit(:admin_notes)
      end

      def calculate_average_processing_time
        processed_applications = PartnerApplication.processed
        return 0 if processed_applications.empty?
        
        total_duration = processed_applications.sum do |app|
          app.processing_duration || 0
        end
        
        (total_duration / processed_applications.count / 1.hour).round(1)
      end
    end
  end
end 