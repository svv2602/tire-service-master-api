module Api
  module V1
    # Controller for client loyalty program endpoints
    class LoyaltyController < BaseController
      skip_after_action :verify_authorized
      # GET /api/v1/loyalty/balance
      # Returns current loyalty balance, level, and progress
      def balance
        account_info = LoyaltyService.balance(current_user)

        render json: {
          success: true,
          data: account_info
        }
      end

      # GET /api/v1/loyalty/transactions
      # Returns paginated list of loyalty transactions
      def transactions
        account = LoyaltyService.find_or_create_account(current_user)
        transactions = account.loyalty_transactions.recent

        # Pagination
        page = (params[:page] || 1).to_i
        per_page = [(params[:per_page] || 20).to_i, 100].min

        total_count = transactions.count
        paginated = transactions.offset((page - 1) * per_page).limit(per_page)

        render json: {
          success: true,
          data: paginated.map { |t| serialize_transaction(t) },
          meta: {
            current_page: page,
            per_page: per_page,
            total_count: total_count,
            total_pages: (total_count.to_f / per_page).ceil
          }
        }
      end

      private

      def serialize_transaction(transaction)
        {
          id: transaction.id,
          points: transaction.points,
          reason: transaction.reason,
          description: transaction.description,
          booking_id: transaction.booking_id,
          tire_order_id: transaction.tire_order_id,
          review_id: transaction.review_id,
          referral_user_id: transaction.referral_user_id,
          created_at: transaction.created_at.iso8601
        }
      end
    end
  end
end
