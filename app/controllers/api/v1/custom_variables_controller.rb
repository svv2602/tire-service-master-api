module Api
  module V1
    class CustomVariablesController < ApiController
      skip_after_action :verify_authorized
      before_action :authenticate_request
      before_action :authorize_admin!
      before_action :set_custom_variable, only: [:show, :update, :destroy]

      # GET /api/v1/custom_variables
      def index
        @custom_variables = CustomVariable.all

        # Фильтрация по активности
        if params[:active].present?
          @custom_variables = @custom_variables.where(is_active: params[:active] == 'true')
        end

        # Фильтрация по категории
        if params[:category].present?
          @custom_variables = @custom_variables.by_category(params[:category])
        end

        # Поиск
        if params[:search].present?
          @custom_variables = @custom_variables.search(params[:search])
        end

        # Сортировка
        sort_by = params[:sort_by] || 'name'
        sort_direction = params[:sort_direction] || 'asc'
        @custom_variables = @custom_variables.order("#{sort_by} #{sort_direction}")

        # Пагинация
        result = paginate(@custom_variables)
        
        render json: {
          data: ActiveModel::Serializer::CollectionSerializer.new(
            result[:data],
            serializer: CustomVariableSerializer
          ),
          pagination: result[:pagination]
        }
      end

      # GET /api/v1/custom_variables/:id
      def show
        render json: @custom_variable, serializer: CustomVariableSerializer
      end

      # POST /api/v1/custom_variables
      def create
        @custom_variable = CustomVariable.new(custom_variable_params)
        @custom_variable.created_by = current_user

        if @custom_variable.save
          render json: @custom_variable, serializer: CustomVariableSerializer, status: :created
        else
          render json: { 
            errors: @custom_variable.errors,
            message: 'Не удалось создать переменную'
          }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/custom_variables/:id
      def update
        if @custom_variable.update(custom_variable_params)
          render json: @custom_variable, serializer: CustomVariableSerializer
        else
          render json: { 
            errors: @custom_variable.errors,
            message: 'Не удалось обновить переменную'
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/custom_variables/:id
      def destroy
        @custom_variable.destroy
        render json: { message: 'Переменная успешно удалена' }
      end

      # GET /api/v1/custom_variables/categories
      def categories
        render json: {
          data: CustomVariable.categories.map do |key, value|
            {
              value: key,
              label: value
            }
          end
        }
      end

      # GET /api/v1/custom_variables/by_category
      def by_category
        variables = CustomVariable.active.includes(:created_by)
        grouped = variables.group_by(&:category)
        
        result = CustomVariable.categories.map do |category_key, category_name|
          {
            category: category_key,
            category_name: category_name,
            variables: grouped[category_key]&.map do |var|
              CustomVariableSerializer.new(var).as_json
            end || []
          }
        end
        
        render json: { data: result }
      end

      private

      def set_custom_variable
        @custom_variable = CustomVariable.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Переменная не найдена' }, status: :not_found
      end

      def custom_variable_params
        params.require(:custom_variable).permit(
          :name, :description, :example_value, :category, :is_active
        )
      end

      def authorize_admin!
        unless current_user&.admin?
          render json: { error: 'Доступ запрещен' }, status: :forbidden
        end
      end
    end
  end
end
