module Api
  module V1
    class SupplierProfileController < ApiController
      before_action :set_supplier

      # GET /api/v1/suppliers/:supplier_id/profile
      def show
        render json: {
          profile: format_profile(@supplier)
        }
      end

      # PATCH /api/v1/suppliers/:supplier_id/profile
      def update
        if @supplier.update(profile_params)
          render json: {
            success: true,
            profile: format_profile(@supplier),
            message: "Профиль успешно обновлен"
          }
        else
          render json: {
            success: false,
            errors: @supplier.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/suppliers/:supplier_id/profile/regenerate_api_key
      def regenerate_api_key
        old_api_key = @supplier.api_key
        @supplier.regenerate_api_key!

        Rails.logger.info "API ключ поставщика #{@supplier.name} (ID: #{@supplier.id}) регенерирован самим поставщиком"

        render json: {
          success: true,
          profile: format_profile(@supplier),
          message: "API ключ успешно регенерирован"
        }
      rescue StandardError => e
        Rails.logger.error "Ошибка регенерации API ключа для поставщика ID #{@supplier.id}: #{e.message}"

        render json: {
          success: false,
          message: "Ошибка при регенерации API ключа",
          error: e.message
        }, status: :internal_server_error
      end

      private

      def set_supplier
        @supplier = Supplier.find(params[:supplier_id])
        authorize_supplier!
      end

      def authorize_supplier!
        unless current_user.admin? || current_user.supplier?
          return render json: {
            success: false,
            error: "Требуются права поставщика"
          }, status: :forbidden
        end

        authorized_supplier = current_user.admin? ? @supplier : current_user.supplier

        if authorized_supplier&.id != @supplier.id
          render json: {
            success: false,
            error: "Доступ запрещен"
          }, status: :forbidden
        end
      end

      def profile_params
        params.require(:profile).permit(
          :name, :email, :phone, :description, :website,
          :contact_person, :address, :telegram_chat_id
        )
      end

      def format_profile(supplier)
        {
          id: supplier.id,
          firm_id: supplier.firm_id,
          name: supplier.name,
          email: supplier.email,
          phone: supplier.phone,
          description: supplier.description,
          website: supplier.website,
          contact_person: supplier.contact_person,
          address: supplier.address,
          api_key: supplier.api_key,
          is_active: supplier.is_active,
          created_at: supplier.created_at,
          last_sync_at: supplier.last_sync_at,
          telegram_chat_id: supplier.telegram_chat_id
        }
      end
    end
  end
end
