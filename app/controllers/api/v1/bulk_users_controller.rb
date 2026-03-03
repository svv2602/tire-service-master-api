# frozen_string_literal: true

module Api
  module V1
    class BulkUsersController < ApiController
      before_action :authenticate_request
      before_action :authorize_admin
      before_action :validate_user_ids

      # POST /api/v1/users/bulk_activate
      # Bulk activate users
      def bulk_activate
        results = process_users do |user|
          authorize user, :manage?, policy_class: UserPolicy
          user.activate!
        end
        render json: build_response(results)
      end

      # POST /api/v1/users/bulk_deactivate
      # Bulk deactivate users
      def bulk_deactivate
        results = process_users do |user|
          authorize user, :manage?, policy_class: UserPolicy
          # Prevent deactivating yourself
          raise 'Cannot deactivate your own account' if user.id == current_user.id
          user.deactivate!
        end
        render json: build_response(results)
      end

      # POST /api/v1/users/bulk_suspend
      # Bulk suspend users with optional reason and duration
      def bulk_suspend
        reason = params[:reason] || 'Bulk suspension'
        duration_days = params[:duration_days]
        until_date = duration_days.present? ? Time.current + duration_days.to_i.days : nil

        results = process_users do |user|
          authorize user, :suspend?, policy_class: UserPolicy
          user.suspend!(
            reason: reason,
            until_date: until_date,
            suspended_by_user: current_user
          )
        end
        render json: build_response(results)
      end

      # POST /api/v1/users/bulk_unsuspend
      # Bulk unsuspend users
      def bulk_unsuspend
        results = process_users do |user|
          authorize user, :unsuspend?, policy_class: UserPolicy
          user.unsuspend!(unsuspended_by_user: current_user)
        end
        render json: build_response(results)
      end

      private

      def authorize_admin
        authorize User, :manage?, policy_class: UserPolicy
      end

      def validate_user_ids
        unless user_ids.is_a?(Array) && user_ids.any?
          render json: { error: 'user_ids must be a non-empty array' }, status: :unprocessable_entity
        end
      end

      def user_ids
        @user_ids ||= Array(params[:user_ids]).map(&:to_i)
      end

      def process_users
        users = User.where(id: user_ids)
        results = { success: [], failed: [] }

        users.find_each do |user|
          begin
            yield(user)
            results[:success] << { id: user.id }
          rescue Pundit::NotAuthorizedError
            results[:failed] << { id: user.id, error: 'Not authorized to perform this action' }
          rescue StandardError => e
            results[:failed] << { id: user.id, error: e.message }
          end
        end

        # Track users that weren't found
        found_ids = users.pluck(:id)
        missing_ids = user_ids - found_ids
        missing_ids.each do |id|
          results[:failed] << { id: id, error: 'User not found' }
        end

        results
      end

      def build_response(results)
        {
          total_requested: user_ids.count,
          success_count: results[:success].count,
          failed_count: results[:failed].count,
          failed: results[:failed]
        }
      end
    end
  end
end
