module Api
  module V1
    # Controller for partner webhook endpoint CRUD operations.
    # Partners can configure webhook URLs to receive event notifications.
    class WebhookEndpointsController < ApiController
      skip_after_action :verify_authorized
      before_action :ensure_partner_or_admin
      before_action :set_partner
      before_action :set_webhook_endpoint, only: [:show, :update, :destroy, :test, :deliveries]

      # GET /api/v1/partners/:partner_id/webhook_endpoints
      def index
        endpoints = @partner.webhook_endpoints
                            .left_joins(:webhook_deliveries)
                            .select('webhook_endpoints.*, COUNT(webhook_deliveries.id) AS deliveries_count_cache')
                            .group('webhook_endpoints.id')
                            .order(created_at: :desc)
        render json: {
          webhook_endpoints: endpoints.map { |ep| serialize_endpoint(ep, use_cache: true) },
          supported_events: WebhookEndpoint::SUPPORTED_EVENTS
        }
      end

      # GET /api/v1/partners/:partner_id/webhook_endpoints/:id
      def show
        render json: {
          webhook_endpoint: serialize_endpoint(@webhook_endpoint)
        }
      end

      # POST /api/v1/partners/:partner_id/webhook_endpoints
      def create
        endpoint = @partner.webhook_endpoints.build(webhook_endpoint_params)

        if endpoint.save
          render json: {
            webhook_endpoint: serialize_endpoint(endpoint),
            secret: endpoint.secret # Show full secret only on creation
          }, status: :created
        else
          render json: { errors: endpoint.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/partners/:partner_id/webhook_endpoints/:id
      def update
        if @webhook_endpoint.update(webhook_endpoint_params)
          render json: {
            webhook_endpoint: serialize_endpoint(@webhook_endpoint)
          }
        else
          render json: { errors: @webhook_endpoint.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/partners/:partner_id/webhook_endpoints/:id
      def destroy
        @webhook_endpoint.destroy!
        render json: { message: 'Webhook endpoint deleted' }
      end

      # POST /api/v1/partners/:partner_id/webhook_endpoints/:id/test
      def test
        delivery = @webhook_endpoint.webhook_deliveries.create!(
          event: 'test.ping',
          payload: {
            event: 'test.ping',
            timestamp: Time.current.iso8601,
            data: { message: 'This is a test webhook delivery' }
          },
          status: 'pending'
        )

        WebhookDeliveryJob.perform_later(delivery.id)

        render json: {
          message: 'Test webhook queued for delivery',
          delivery_id: delivery.id
        }
      end

      # GET /api/v1/partners/:partner_id/webhook_endpoints/:id/deliveries
      def deliveries
        deliveries_scope = @webhook_endpoint.webhook_deliveries.recent
        paginated_data = paginate(deliveries_scope)

        render json: {
          deliveries: paginated_data[:data].map { |d| serialize_delivery(d) },
          pagination: paginated_data[:pagination]
        }
      end

      private

      def ensure_partner_or_admin
        unless current_user&.partner? || current_user&.admin?
          render json: { error: 'Access denied' }, status: :forbidden
        end
      end

      def set_partner
        if current_user.admin?
          @partner = Partner.find(params[:partner_id])
        else
          @partner = current_user.partner
          if params[:partner_id].to_i != @partner.id
            render json: { error: 'Access denied' }, status: :forbidden
            return
          end
        end
      end

      def set_webhook_endpoint
        @webhook_endpoint = @partner.webhook_endpoints.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Webhook endpoint not found' }, status: :not_found
      end

      def webhook_endpoint_params
        params.permit(:url, :description, :is_active, events: [])
      end

      def serialize_endpoint(endpoint, use_cache: false)
        {
          id: endpoint.id,
          url: endpoint.url,
          events: endpoint.events,
          is_active: endpoint.is_active,
          description: endpoint.description,
          secret_masked: mask_secret(endpoint.secret),
          deliveries_count: use_cache && endpoint.respond_to?(:deliveries_count_cache) ? endpoint.deliveries_count_cache.to_i : endpoint.webhook_deliveries.count,
          last_delivery_at: endpoint.webhook_deliveries.where(status: 'success')
                                   .order(delivered_at: :desc).pick(:delivered_at),
          created_at: endpoint.created_at,
          updated_at: endpoint.updated_at
        }
      end

      def serialize_delivery(delivery)
        {
          id: delivery.id,
          event: delivery.event,
          status: delivery.status,
          response_code: delivery.response_code,
          attempt: delivery.attempt,
          delivered_at: delivery.delivered_at,
          error_message: delivery.error_message,
          created_at: delivery.created_at
        }
      end

      def mask_secret(secret)
        return '********' unless secret && secret.length > 8

        "#{'*' * (secret.length - 8)}#{secret[-8..]}"
      end
    end
  end
end
