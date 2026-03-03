# frozen_string_literal: true

module Api
  module V1
    class CsrfController < ApplicationController
      # Skip authentication - CSRF token should be available without auth
      skip_before_action :authenticate_request, raise: false
      skip_after_action :verify_authorized

      # GET /api/v1/csrf
      # Returns CSRF token for frontend to use in subsequent requests
      def show
        render json: { csrf_token: form_authenticity_token }
      end
    end
  end
end
