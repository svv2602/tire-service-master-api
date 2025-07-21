module Api
  module V1
    class EmailTemplatesController < ApiController
      before_action :authenticate_request
      before_action :authorize_admin!
      before_action :set_email_template, only: [:show, :update, :destroy, :preview]

      # GET /api/v1/email_templates
      def index
        @email_templates = EmailTemplate.all

        # Фильтрация по активности
        if params[:active].present?
          @email_templates = @email_templates.where(is_active: params[:active] == 'true')
        end

        # Фильтрация по типу шаблона
        if params[:template_type].present?
          @email_templates = @email_templates.by_type(params[:template_type])
        end

        # Фильтрация по языку
        if params[:language].present?
          @email_templates = @email_templates.by_language(params[:language])
        end

        # Поиск по названию, теме или описанию
        if params[:search].present?
          search_term = "%#{params[:search].downcase}%"
          @email_templates = @email_templates.where(
            "LOWER(name) LIKE ? OR LOWER(subject) LIKE ? OR LOWER(description) LIKE ?",
            search_term, search_term, search_term
          )
        end

        # Сортировка
        sort_by = params[:sort_by] || 'created_at'
        sort_direction = params[:sort_direction] || 'desc'
        @email_templates = @email_templates.order("#{sort_by} #{sort_direction}")

        # Пагинация
        result = paginate(@email_templates)
        
        render json: {
          data: ActiveModel::Serializer::CollectionSerializer.new(
            result[:data],
            serializer: EmailTemplateSerializer
          ),
          pagination: result[:pagination]
        }
      end

      # GET /api/v1/email_templates/:id
      def show
        render json: @email_template, serializer: EmailTemplateSerializer
      end

      # POST /api/v1/email_templates
      def create
        @email_template = EmailTemplate.new(email_template_params)

        if @email_template.save
          render json: @email_template, serializer: EmailTemplateSerializer, status: :created
        else
          render json: { 
            errors: @email_template.errors,
            message: 'Не удалось создать шаблон email'
          }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/email_templates/:id
      def update
        if @email_template.update(email_template_params)
          render json: @email_template, serializer: EmailTemplateSerializer
        else
          render json: { 
            errors: @email_template.errors,
            message: 'Не удалось обновить шаблон email'
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/email_templates/:id
      def destroy
        @email_template.destroy
        render json: { message: 'Шаблон email успешно удален' }
      end

      # POST /api/v1/email_templates/:id/preview
      def preview
        variable_values = params[:variables] || {}
        
        rendered = @email_template.render_with_variables(variable_values)
        
        render json: {
          subject: rendered[:subject],
          body: rendered[:body],
          variables: @email_template.variables_array
        }
      end

      # GET /api/v1/email_templates/template_types
      def template_types
        render json: {
          data: EmailTemplate.template_types.map do |key, value|
            {
              value: key,
              label: value
            }
          end
        }
      end

      private

      def set_email_template
        @email_template = EmailTemplate.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Шаблон email не найден' }, status: :not_found
      end

      def email_template_params
        permitted = params.require(:email_template).permit(
          :name, :subject, :body, :template_type, :language, 
          :is_active, :description, variables: []
        )
        
        # Преобразуем массив variables в JSON
        if permitted[:variables].is_a?(Array)
          permitted[:variables] = permitted[:variables].to_json
        end
        
        permitted
      end

      def authorize_admin!
        unless current_user&.admin?
          render json: { error: 'Доступ запрещен' }, status: :forbidden
        end
      end
    end
  end
end 