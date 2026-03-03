# frozen_string_literal: true

module Api
  module V1
    class OnboardingController < ApiController
      skip_after_action :verify_authorized
      before_action :authenticate_request

      # GET /api/v1/onboarding/progress
      # Get current user's onboarding progress
      def progress
        onboarding = find_or_create_progress

        render json: {
          data: format_progress(onboarding)
        }
      end

      # PATCH /api/v1/onboarding/progress
      # Update onboarding progress (mark step as completed or set welcome_shown)
      def update_progress
        onboarding = find_or_create_progress

        if params[:completed_step].present?
          onboarding.mark_step_completed!(params[:completed_step])
        end

        if params.key?(:welcome_shown)
          onboarding.update!(welcome_shown: params[:welcome_shown])
        end

        render json: {
          data: format_progress(onboarding)
        }
      end

      private

      def find_or_create_progress
        OnboardingProgress.find_or_create_by!(user: current_user)
      end

      def format_progress(onboarding)
        {
          role: onboarding.role,
          completed_steps: onboarding.completed_steps,
          current_step: onboarding.current_step,
          welcome_shown: onboarding.welcome_shown,
          progress_percent: onboarding.progress_percent,
          steps: onboarding.steps
        }
      end
    end
  end
end
