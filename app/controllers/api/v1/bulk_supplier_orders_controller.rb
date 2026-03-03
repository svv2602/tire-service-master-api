# frozen_string_literal: true

module Api
  module V1
    class BulkSupplierOrdersController < ApiController
      before_action :authenticate_request
      before_action :ensure_supplier_access!
      before_action :set_supplier
      before_action :validate_order_ids

      # POST /api/v1/suppliers/:supplier_id/orders/bulk_confirm
      # Bulk confirm orders
      def bulk_confirm
        results = process_orders(:confirm!)
        render json: build_response(results)
      end

      # POST /api/v1/suppliers/:supplier_id/orders/bulk_start_processing
      # Bulk start processing orders
      def bulk_start_processing
        results = process_orders(:start_processing!)
        render json: build_response(results)
      end

      # POST /api/v1/suppliers/:supplier_id/orders/bulk_ship
      # Bulk ship orders with optional tracking number
      def bulk_ship
        tracking_number = params[:tracking_number]
        results = process_orders(:ship!) do |order|
          order.tracking_number = tracking_number if tracking_number.present?
        end
        render json: build_response(results)
      end

      # POST /api/v1/suppliers/:supplier_id/orders/bulk_cancel
      # Bulk cancel orders with optional reason
      def bulk_cancel
        results = process_orders(:cancel!) do |order|
          order.notes = [order.notes, params[:reason]].compact.join("\n") if params[:reason].present?
        end
        render json: build_response(results)
      end

      private

      def ensure_supplier_access!
        unless current_user.admin? || current_user.supplier?
          render json: { error: 'Access denied' }, status: :forbidden
        end
      end

      def set_supplier
        @supplier = if current_user.admin?
                      Supplier.find(params[:supplier_id])
                    else
                      current_user.supplier
                    end

        render json: { error: 'Supplier not found' }, status: :not_found unless @supplier
      end

      def validate_order_ids
        unless order_ids.is_a?(Array) && order_ids.any?
          render json: { error: 'order_ids must be a non-empty array' }, status: :unprocessable_entity
        end
      end

      def order_ids
        @order_ids ||= Array(params[:order_ids]).map(&:to_i)
      end

      def process_orders(action_method)
        orders = @supplier.tire_orders.where(id: order_ids)
        results = { success: [], failed: [] }

        orders.find_each do |order|
          begin
            # Apply optional block before action (e.g., setting tracking number)
            yield(order) if block_given?

            order.send(action_method)
            results[:success] << { id: order.id, status: order.status }
          rescue AASM::InvalidTransition => e
            results[:failed] << { id: order.id, error: "Cannot perform action from status '#{order.status}'" }
          rescue StandardError => e
            results[:failed] << { id: order.id, error: e.message }
          end
        end

        # Track orders that weren't found
        found_ids = orders.pluck(:id)
        missing_ids = order_ids - found_ids
        missing_ids.each do |id|
          results[:failed] << { id: id, error: 'Order not found' }
        end

        results
      end

      def build_response(results)
        {
          total_requested: order_ids.count,
          success_count: results[:success].count,
          failed_count: results[:failed].count,
          successful: results[:success],
          failed: results[:failed]
        }
      end
    end
  end
end
