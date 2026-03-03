module Api
  module V1
    class ServicePointStatusesController < ApplicationController
      skip_after_action :verify_authorized
      def index
        @statuses = ServicePointStatus.active.sorted
        render json: @statuses
      end
    end
  end
end 